import 'measurement.dart';
import 'ovy_protocol.dart';

/// A thermometer discovered during a BLE scan. Identified by its platform [id];
/// the address is discovered, never hardcoded, so any Ovy unit can be paired.
class DiscoveredThermometer {
  final String id;
  final String name;

  const DiscoveredThermometer({required this.id, required this.name});

  @override
  bool operator ==(Object other) =>
      other is DiscoveredThermometer && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

/// The measurements and device state from a completed sync.
class SyncResult {
  final List<Measurement> measurements;
  final int? batteryPercent;

  const SyncResult({required this.measurements, this.batteryPercent});
}

/// Live status of a maintained connection to the thermometer. [connected] is
/// true while the link is up; [rssi] (dBm) and [batteryPercent] are known only
/// while connected.
class ThermometerStatus {
  final bool connected;
  final int? rssi;
  final int? batteryPercent;

  const ThermometerStatus({
    this.connected = false,
    this.rssi,
    this.batteryPercent,
  });

  ThermometerStatus copyWith({
    bool? connected,
    int? rssi,
    int? batteryPercent,
  }) {
    return ThermometerStatus(
      connected: connected ?? this.connected,
      rssi: rssi ?? this.rssi,
      batteryPercent: batteryPercent ?? this.batteryPercent,
    );
  }
}

/// Talks to an Ovy thermometer over BLE.
///
/// An interface so the UI and repository can be driven by a fake in tests and on
/// platforms that cannot do BLE at all (for example the web build). The concrete
/// `flutter_blue_plus` implementation is provided on mobile.
abstract interface class ThermometerService {
  /// Scan for advertising Ovy thermometers, filtered by name and the custom
  /// service. Emits the growing list of devices seen so far.
  Stream<List<DiscoveredThermometer>> scan();

  /// Start bonding with [device]. This triggers the platform's own pairing
  /// dialog; the six-digit passkey the thermometer then displays is entered into
  /// that system dialog, not collected by the app.
  Future<void> pair(DiscoveredThermometer device);

  /// Open a maintained, auto-reconnecting connection to the paired [deviceId].
  /// The session connects as soon as the device advertises and stays connected,
  /// avoiding repeated scan/connect churn. Close it when no longer needed.
  ThermometerSession openSession(String deviceId);
}

/// A maintained connection to a paired thermometer. Holds one BLE link open and
/// reconnects automatically when the device wakes, rather than reconnecting per
/// operation.
abstract interface class ThermometerSession {
  /// The live connection status: connected state, signal strength, and battery.
  /// Replays the latest value to new listeners.
  Stream<ThermometerStatus> get status;

  /// Pull the stored history over the open connection. The session must be
  /// connected; on the Ovy the records stream once per connection.
  Future<SyncResult> sync();

  /// Disconnect and stop maintaining the connection.
  Future<void> close();
}

/// In-memory [ThermometerService] that replays canned measurements. Used by the
/// web build, widget tests, and local development where no device is present.
class FakeThermometerService implements ThermometerService {
  final List<Measurement> measurements;
  final int batteryPercent;

  FakeThermometerService({
    this.measurements = const [],
    this.batteryPercent = 84,
  });

  @override
  Stream<List<DiscoveredThermometer>> scan() async* {
    yield const [
      DiscoveredThermometer(id: 'fake-ot35', name: OvyGatt.advertisedName),
    ];
  }

  @override
  Future<void> pair(DiscoveredThermometer device) async {}

  @override
  ThermometerSession openSession(String deviceId) => FakeThermometerSession(
    measurements: measurements,
    battery: batteryPercent,
  );
}

/// In-memory [ThermometerSession] that reports a connected device and replays
/// canned measurements.
class FakeThermometerSession implements ThermometerSession {
  final List<Measurement> measurements;
  final int battery;

  FakeThermometerSession({this.measurements = const [], this.battery = 84});

  @override
  Stream<ThermometerStatus> get status => Stream.value(
    ThermometerStatus(connected: true, rssi: -50, batteryPercent: battery),
  );

  @override
  Future<SyncResult> sync() async =>
      SyncResult(measurements: List.of(measurements), batteryPercent: battery);

  @override
  Future<void> close() async {}
}
