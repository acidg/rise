import '../ble/thermometer_service.dart';

/// Durable record of the thermometer the user has paired, so the app remembers
/// it across launches. The operating system keeps the BLE bond; this keeps the
/// app's own memory of which device was chosen.
abstract interface class PairedDeviceStore {
  /// The stored device, or null if none has been paired.
  Future<DiscoveredThermometer?> load();

  /// Remember [device] as the paired thermometer.
  Future<void> save(DiscoveredThermometer device);

  /// Forget the paired thermometer.
  Future<void> clear();
}

/// In-memory [PairedDeviceStore] for tests and platforms without persistence.
class InMemoryPairedDeviceStore implements PairedDeviceStore {
  DiscoveredThermometer? _device;

  InMemoryPairedDeviceStore([this._device]);

  @override
  Future<DiscoveredThermometer?> load() async => _device;

  @override
  Future<void> save(DiscoveredThermometer device) async => _device = device;

  @override
  Future<void> clear() async => _device = null;
}
