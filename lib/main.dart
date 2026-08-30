import 'package:flutter/material.dart';

import 'app.dart';
import 'ble/thermometer_service_factory.dart';
import 'data/entry_repository.dart';
import 'data/sample_data.dart';
import 'data/shared_preferences_paired_device_store.dart';
import 'ui/app_controller.dart';

void main() {
  // Demo wiring: an in-memory store seeded with sample cycles, plus the real
  // BLE thermometer on mobile (a fake elsewhere) and a persisted paired device.
  // The entry persistence layer is still in-memory and replaces the repository
  // without touching the UI.
  final repository = InMemoryEntryRepository(generateSampleEntries());
  final controller = AppController(
    repository: repository,
    thermometer: createThermometerService(),
    pairedDeviceStore: SharedPreferencesPairedDeviceStore(),
  );
  runApp(RiseApp(controller: controller));
}
