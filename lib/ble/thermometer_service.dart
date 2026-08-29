import 'measurement.dart';
import 'ovy_protocol.dart';

/// A thermometer discovered during a BLE scan. Identified by its platform [id];
/// the address is discovered, never hardcoded, so any Ovy unit can be paired.
class DiscoveredThermometer {
  final String id;
  final String name;

  const DiscoveredThermometer({required this.id, required this.name});
}

/// The measurements and device state from a completed sync.
class SyncResult {
  final List<Measurement> measurements;
  final int? batteryPercent;

  const SyncResult({required this.measurements, this.batteryPercent});
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

  /// Bond with [device] using the six-digit [pin] shown on its display.
  Future<void> pair(DiscoveredThermometer device, String pin);

  /// Connect to the bonded [device], pull its stored history, and disconnect.
  Future<SyncResult> sync(DiscoveredThermometer device);
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
  Future<void> pair(DiscoveredThermometer device, String pin) async {}

  @override
  Future<SyncResult> sync(DiscoveredThermometer device) async {
    return SyncResult(
      measurements: List.of(measurements),
      batteryPercent: batteryPercent,
    );
  }
}
