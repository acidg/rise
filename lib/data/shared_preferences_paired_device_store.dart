import 'package:shared_preferences/shared_preferences.dart';

import '../ble/thermometer_service.dart';
import 'paired_device_store.dart';

/// [PairedDeviceStore] backed by `shared_preferences`, so the paired thermometer
/// survives app restarts. Stores only the platform id and display name; the BLE
/// bond itself is kept by the operating system.
class SharedPreferencesPairedDeviceStore implements PairedDeviceStore {
  static const String _idKey = 'paired_device_id';
  static const String _nameKey = 'paired_device_name';

  @override
  Future<DiscoveredThermometer?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_idKey);
    final name = prefs.getString(_nameKey);
    if (id == null || name == null) {
      return null;
    }
    return DiscoveredThermometer(id: id, name: name);
  }

  @override
  Future<void> save(DiscoveredThermometer device) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_idKey, device.id);
    await prefs.setString(_nameKey, device.name);
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_idKey);
    await prefs.remove(_nameKey);
  }
}
