import 'package:flutter_test/flutter_test.dart';
import 'package:rise/ble/measurement.dart';
import 'package:rise/ble/thermometer_service.dart';
import 'package:rise/data/entry_repository.dart';
import 'package:rise/data/paired_device_store.dart';
import 'package:rise/domain/models/day_entry.dart';
import 'package:rise/domain/models/signs.dart';
import 'package:rise/ui/app_controller.dart';

void main() {
  test(
    'saving an edited entry is reflected in the chart day for that date',
    () async {
      final target = DateTime(2026, 3, 1);
      final entries = [
        DayEntry(
          date: target,
          temperature: 36.40,
          menstruation: Menstruation.medium,
        ),
        DayEntry(date: DateTime(2026, 3, 2), temperature: 36.45),
      ];
      final controller = AppController(
        repository: InMemoryEntryRepository(entries),
        thermometer: FakeThermometerService(),
      );
      await controller.load();

      final original = controller.days.firstWhere((d) => d.date == target);
      await controller.saveEntry(
        original.entry.copyWith(temperature: 37.10, notes: 'edited'),
      );

      final updated = controller.days.firstWhere((d) => d.date == target);
      expect(updated.temperature, 37.10);
      expect(updated.entry.notes, 'edited');
      expect(updated.hasEntry, isTrue);
    },
  );

  test(
    'importing measurements sets temperatures while keeping logged signs',
    () async {
      final logged = DateTime(2026, 3, 1);
      final controller = AppController(
        repository: InMemoryEntryRepository([
          DayEntry(date: logged, menstruation: Menstruation.medium),
        ]),
        thermometer: FakeThermometerService(),
      );
      await controller.load();

      await controller.importMeasurements([
        Measurement(timestamp: DateTime(2026, 3, 1, 6, 30), celsius: 36.55),
        Measurement(timestamp: DateTime(2026, 3, 2, 6, 30), celsius: 36.60),
      ]);

      final first = controller.days.firstWhere((d) => d.date == logged);
      expect(first.temperature, 36.55);
      // The sync must not clobber signs the user logged that day.
      expect(first.entry.menstruation, Menstruation.medium);
      final second = controller.days.firstWhere(
        (d) => d.date == DateTime(2026, 3, 2),
      );
      expect(second.temperature, 36.60);
    },
  );

  test('multiple readings for one day collapse to the earliest', () async {
    final controller = AppController(
      repository: InMemoryEntryRepository(const []),
      thermometer: FakeThermometerService(),
    );
    await controller.load();

    await controller.importMeasurements([
      Measurement(timestamp: DateTime(2026, 3, 1, 9, 0), celsius: 36.90),
      Measurement(timestamp: DateTime(2026, 3, 1, 6, 30), celsius: 36.55),
    ]);

    final day = controller.days.firstWhere(
      (d) => d.date == DateTime(2026, 3, 1),
    );
    expect(day.temperature, 36.55);
  });

  test('a remembered paired device is loaded on startup', () async {
    const device = DiscoveredThermometer(id: 'AA:BB', name: 'Ovy OT35');
    final controller = AppController(
      repository: InMemoryEntryRepository(const []),
      thermometer: FakeThermometerService(),
      pairedDeviceStore: InMemoryPairedDeviceStore(device),
    );

    await controller.load();

    expect(controller.pairedDevice, device);
  });

  test('remembering then forgetting a device persists to the store', () async {
    const device = DiscoveredThermometer(id: 'AA:BB', name: 'Ovy OT35');
    final store = InMemoryPairedDeviceStore();
    final controller = AppController(
      repository: InMemoryEntryRepository(const []),
      thermometer: FakeThermometerService(),
      pairedDeviceStore: store,
    );
    await controller.load();

    await controller.rememberPairedDevice(device);
    expect(controller.pairedDevice, device);
    expect(await store.load(), device);

    await controller.forgetPairedDevice();
    expect(controller.pairedDevice, isNull);
    expect(await store.load(), isNull);
  });
}
