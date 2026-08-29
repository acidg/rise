import 'package:flutter/material.dart';

import 'app.dart';
import 'ble/thermometer_service.dart';
import 'data/entry_repository.dart';
import 'data/sample_data.dart';
import 'ui/app_controller.dart';

void main() {
  // Demo wiring: an in-memory store seeded with sample cycles and a fake
  // thermometer. The real persistence and BLE implementations replace these
  // without touching the UI.
  final repository = InMemoryEntryRepository(generateSampleEntries());
  final controller = AppController(
    repository: repository,
    thermometer: FakeThermometerService(),
  );
  runApp(RiseApp(controller: controller));
}
