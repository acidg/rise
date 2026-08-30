import 'package:flutter/material.dart';

import 'app.dart';
import 'ble/thermometer_service_factory.dart';
import 'data/shared_preferences_entry_repository.dart';
import 'data/shared_preferences_paired_device_store.dart';
import 'ui/app_controller.dart';

void main() {
  // Real wiring: the day history and paired device both persist across launches,
  // and temperatures come from syncing the physical thermometer (a fake stands in
  // on platforms without BLE). The history starts empty and fills as the user
  // syncs and logs.
  final controller = AppController(
    repository: SharedPreferencesEntryRepository(),
    thermometer: createThermometerService(),
    pairedDeviceStore: SharedPreferencesPairedDeviceStore(),
  );
  runApp(RiseApp(controller: controller));
}
