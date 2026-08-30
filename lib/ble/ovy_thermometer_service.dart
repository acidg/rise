import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'measurement.dart';
import 'ovy_protocol.dart';
import 'thermometer_service.dart';

/// How long a discovery scan runs before it stops on its own. Generous, because
/// the OT35 advertises only a short burst each time its wake button is pressed.
const Duration _scanTimeout = Duration(seconds: 60);

/// How long to wait for a connection to establish.
const Duration _connectTimeout = Duration(seconds: 20);

/// How long a (re)connect waits for the device to advertise before giving up and
/// scanning again. The maintain loop retries, so this only bounds one attempt.
const Duration _wakeTimeout = Duration(seconds: 60);

/// The history dump is complete once no record has arrived for this long. The
/// device streams its stored records back to back, so a short gap means the end.
const Duration _quietPeriod = Duration(seconds: 3);

/// Absolute cap on a single history pull, so a stalled stream still returns.
const Duration _syncTimeout = Duration(seconds: 45);

/// Cap on short GATT reads (battery, RSSI, service discovery) so they cannot hang.
const Duration _shortReadTimeout = Duration(seconds: 8);

/// How often to refresh the signal strength while connected.
const Duration _rssiInterval = Duration(seconds: 3);

/// Real [ThermometerService] backed by `flutter_blue_plus`. Used on Android and
/// iOS; other platforms fall back to the fake (see the service factory).
class OvyThermometerService implements ThermometerService {
  @override
  Stream<List<DiscoveredThermometer>> scan() async* {
    if (!await FlutterBluePlus.isSupported) {
      throw const ThermometerException(
        'Bluetooth is not supported on this device.',
      );
    }
    await _ensureAdapterOn();

    final seen = <String, DiscoveredThermometer>{};
    await FlutterBluePlus.stopScan();
    await FlutterBluePlus.startScan(timeout: _scanTimeout);
    try {
      await for (final results in FlutterBluePlus.scanResults) {
        for (final result in results.where(_isOvy)) {
          final id = result.device.remoteId.str;
          seen[id] = DiscoveredThermometer(id: id, name: _nameOf(result));
        }
        yield seen.values.toList(growable: false);
        if (!FlutterBluePlus.isScanningNow) {
          break;
        }
      }
    } finally {
      await FlutterBluePlus.stopScan();
    }
  }

  @override
  Future<void> pair(DiscoveredThermometer device) async {
    final target = await _connectOnWake(device.id);
    try {
      // Passkey-entry pairing: createBond starts the pairing procedure, which
      // makes the thermometer display its six-digit passkey and makes Android
      // show its own dialog to enter it. flutter_blue_plus cannot submit the
      // passkey itself; iOS bonds implicitly on the first encrypted read.
      if (defaultTargetPlatform == TargetPlatform.android) {
        await target.createBond();
      }
    } finally {
      await target.disconnect();
    }
  }

  @override
  ThermometerSession openSession(String deviceId) => OvySession(deviceId);
}

/// A maintained connection to the Ovy thermometer. Holds one BLE link open -
/// like the official app and nRF Connect - rather than reconnecting per
/// operation, which avoids scan throttling and connection churn. When the device
/// sleeps and the link drops, it scans and reconnects as soon as it wakes again.
///
/// The BLE handshake follows the reverse-engineered Ovy OT35 protocol: set the
/// device clock via the Current Time Service, subscribe to the data
/// characteristics, then write the history-request command; the device replies
/// with its stored records as indications on the first subscribe of a connection.
class OvySession implements ThermometerSession {
  final String _id;
  BluetoothDevice _device;
  final StreamController<ThermometerStatus> _controller =
      StreamController<ThermometerStatus>.broadcast();
  ThermometerStatus _status = const ThermometerStatus();
  Timer? _rssiTimer;
  List<BluetoothService>? _services;
  bool _closed = false;

  OvySession(this._id) : _device = BluetoothDevice.fromId(_id) {
    unawaited(_maintain());
  }

  @override
  Stream<ThermometerStatus> get status async* {
    yield _status;
    yield* _controller.stream;
  }

  /// Keep a connection up: connect when the device advertises, hold it open, and
  /// reconnect after it drops, until [close] is called.
  Future<void> _maintain() async {
    while (!_closed) {
      try {
        _device = await _connectOnWake(_id);
      } on Exception {
        // Adapter off, or the device did not wake within the window; try again.
        continue;
      }
      if (_closed) {
        await _safeDisconnect();
        return;
      }
      await _onConnected();
      try {
        await _device.connectionState.firstWhere(
          (s) => s == BluetoothConnectionState.disconnected,
        );
      } on Exception {
        // Ignore; fall through to the disconnected handling and reconnect.
      }
      _onDisconnected();
    }
  }

  Future<void> _onConnected() async {
    _services = null;
    _emit(const ThermometerStatus(connected: true));
    try {
      _services = await _device.discoverServices().timeout(_shortReadTimeout);
      final battery = await _readBattery(
        _OvyChars.discover(_services!).battery,
      );
      if (battery != null) {
        _emit(_status.copyWith(batteryPercent: battery));
      }
    } on Exception {
      // Battery/discovery are best-effort; the link is still usable for sync.
    }
    _startRssi();
  }

  void _onDisconnected() {
    _rssiTimer?.cancel();
    _rssiTimer = null;
    _services = null;
    _emit(const ThermometerStatus(connected: false));
  }

  void _startRssi() {
    _rssiTimer?.cancel();
    _rssiTimer = Timer.periodic(_rssiInterval, (_) async {
      if (_closed || !_device.isConnected) {
        return;
      }
      try {
        final rssi = await _device.readRssi().timeout(_shortReadTimeout);
        _emit(_status.copyWith(rssi: rssi));
      } on Exception {
        // A missed RSSI sample is harmless.
      }
    });
  }

  void _emit(ThermometerStatus status) {
    _status = status;
    if (!_controller.isClosed) {
      _controller.add(status);
    }
  }

  @override
  Future<SyncResult> sync() async {
    if (!_device.isConnected) {
      throw const ThermometerException('Thermometer is not connected.');
    }
    final services = _services ??= await _device.discoverServices().timeout(
      _shortReadTimeout,
    );
    final chars = _OvyChars.discover(services);
    final battery = await _readBattery(chars.battery);
    await _writeCurrentTime(chars.currentTime);
    final measurements = await _pullHistory(_device, chars);
    await _acknowledge(chars.command);
    if (battery != null) {
      _emit(_status.copyWith(batteryPercent: battery));
    }
    return SyncResult(
      measurements: measurements,
      batteryPercent: battery ?? _status.batteryPercent,
    );
  }

  @override
  Future<void> close() async {
    _closed = true;
    _rssiTimer?.cancel();
    await FlutterBluePlus.stopScan();
    await _safeDisconnect();
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }

  Future<void> _safeDisconnect() async {
    try {
      await _device.disconnect();
    } on Exception {
      // Already disconnected.
    }
  }
}

/// Connect the reliable way: scan until the device is seen advertising, then
/// immediately do a direct connect while it is still connectable. The OT35 only
/// advertises a short burst per wake-button press, so a direct connect issued out
/// of the blue usually misses it; connecting off a fresh sighting is what nRF
/// Connect does. Waits up to [timeout] for the device to appear.
Future<BluetoothDevice> _connectOnWake(
  String id, {
  Duration timeout = _wakeTimeout,
}) async {
  await _ensureAdapterOn();
  await FlutterBluePlus.stopScan();
  await FlutterBluePlus.startScan(timeout: timeout);
  try {
    await FlutterBluePlus.scanResults
        .expand((results) => results)
        .map((result) => result.device.remoteId.str)
        .firstWhere((seenId) => seenId == id)
        .timeout(timeout);
  } on TimeoutException {
    throw const ThermometerException(
      'Lost contact with the thermometer. Wake it and try again.',
    );
  } finally {
    await FlutterBluePlus.stopScan();
  }

  final target = BluetoothDevice.fromId(id);
  await target.connect(timeout: _connectTimeout, license: License.nonprofit);
  return target;
}

/// Subscribe to the data characteristics, request the history, and collect the
/// records until the stream goes quiet or the overall timeout elapses.
Future<List<Measurement>> _pullHistory(
  BluetoothDevice device,
  _OvyChars chars,
) async {
  final data = chars.data;
  final control = chars.control;
  if (data == null || control == null) {
    throw const ThermometerException(
      'Thermometer is missing its data characteristics.',
    );
  }

  final measurements = <Measurement>[];
  final done = Completer<void>();
  Timer? quiet;
  void markActivity() {
    quiet?.cancel();
    quiet = Timer(_quietPeriod, () {
      if (!done.isCompleted) {
        done.complete();
      }
    });
  }

  void onValue(List<int> value) {
    markActivity();
    try {
      measurements.add(parseMeasurementRecord(value));
    } on FormatException {
      // Ignore frames that are not measurement records, e.g. status
      // indications on the secondary channel.
    }
  }

  final subscriptions = <StreamSubscription<List<int>>>[
    data.onValueReceived.listen(onValue),
    if (chars.data2 != null) chars.data2!.onValueReceived.listen(onValue),
  ];
  for (final subscription in subscriptions) {
    device.cancelWhenDisconnected(subscription);
  }

  try {
    await data.setNotifyValue(true);
    if (chars.data2 != null) {
      await chars.data2!.setNotifyValue(true);
    }
    await control.write(OvyGatt.requestHistory);
    markActivity();
    await done.future.timeout(_syncTimeout);
  } on TimeoutException {
    // Return whatever arrived before the stall.
  } finally {
    quiet?.cancel();
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
  }
  return measurements;
}

Future<int?> _readBattery(BluetoothCharacteristic? battery) async {
  if (battery == null) {
    return null;
  }
  try {
    final value = await battery.read().timeout(_shortReadTimeout);
    return value.isEmpty ? null : value.first;
  } on Exception {
    return null;
  }
}

Future<void> _writeCurrentTime(BluetoothCharacteristic? currentTime) async {
  if (currentTime == null) {
    return;
  }
  await currentTime.write(buildCurrentTimePayload(DateTime.now()));
}

Future<void> _acknowledge(BluetoothCharacteristic? command) async {
  if (command == null) {
    return;
  }
  try {
    await command.write(OvyGatt.acknowledge);
  } on Exception {
    // The sync already succeeded; a failed acknowledge is not fatal.
  }
}

Future<void> _ensureAdapterOn() async {
  if (FlutterBluePlus.adapterStateNow == BluetoothAdapterState.on) {
    return;
  }
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await FlutterBluePlus.turnOn();
  }
  final state = await FlutterBluePlus.adapterState
      .firstWhere((s) => s == BluetoothAdapterState.on)
      .timeout(_connectTimeout, onTimeout: () => BluetoothAdapterState.off);
  if (state != BluetoothAdapterState.on) {
    throw const ThermometerException('Bluetooth is turned off.');
  }
}

bool _isOvy(ScanResult result) {
  final adv = result.advertisementData;
  if (adv.manufacturerData.containsKey(OvyGatt.manufacturerId)) {
    return true;
  }
  final name = result.device.platformName.isNotEmpty
      ? result.device.platformName
      : adv.advName;
  if (name.toLowerCase().contains('ovy')) {
    return true;
  }
  return adv.serviceUuids.any((uuid) => _isUuid(uuid, OvyGatt.customService));
}

String _nameOf(ScanResult result) {
  final platformName = result.device.platformName;
  if (platformName.isNotEmpty) {
    return platformName;
  }
  final advName = result.advertisementData.advName;
  return advName.isEmpty ? OvyGatt.advertisedName : advName;
}

/// Thrown when a BLE operation fails in a way worth showing to the user.
class ThermometerException implements Exception {
  final String message;

  const ThermometerException(this.message);

  @override
  String toString() => message;
}

/// The Ovy characteristics resolved from a connected device's GATT table.
///
/// Characteristics are matched by their short UUID so handle numbers, which vary
/// between firmware revisions, never leak into the protocol code.
class _OvyChars {
  final BluetoothCharacteristic? data;
  final BluetoothCharacteristic? data2;
  final BluetoothCharacteristic? command;
  final BluetoothCharacteristic? control;
  final BluetoothCharacteristic? currentTime;
  final BluetoothCharacteristic? battery;

  const _OvyChars({
    this.data,
    this.data2,
    this.command,
    this.control,
    this.currentTime,
    this.battery,
  });

  factory _OvyChars.discover(List<BluetoothService> services) {
    final all = [for (final s in services) ...s.characteristics];
    BluetoothCharacteristic? find(String shortUuid) {
      for (final c in all) {
        if (_isUuid(c.uuid, shortUuid)) {
          return c;
        }
      }
      return null;
    }

    return _OvyChars(
      data: find(OvyGatt.dataOut),
      data2: find(OvyGatt.dataOut2),
      command: find(OvyGatt.command),
      control: find(OvyGatt.control),
      currentTime: find(OvyGatt.currentTime),
      battery: find(OvyGatt.batteryLevel),
    );
  }
}

/// Whether [uuid] is the given 16-bit [shortUuid]. flutter_blue_plus expands
/// short UUIDs to their full 128-bit form, so a substring match is enough.
bool _isUuid(Guid uuid, String shortUuid) =>
    uuid.str.toLowerCase().contains(shortUuid.toLowerCase());
