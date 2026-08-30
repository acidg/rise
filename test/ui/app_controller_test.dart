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
      // The measurement's time comes across from the device clock.
      expect(first.entry.temperatureAt, DateTime(2026, 3, 1, 6, 30));
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

  test(
    'a diverging reading is kept out until the resolver confirms it',
    () async {
      final day = DateTime(2026, 3, 1);
      final controller = AppController(
        repository: InMemoryEntryRepository([
          DayEntry(
            date: day,
            temperature: 36.40,
            temperatureAt: DateTime(2026, 3, 1, 6, 0),
          ),
        ]),
        thermometer: FakeThermometerService(),
      );
      await controller.load();

      final conflicts = <TemperatureConflict>[];
      await controller.importMeasurements(
        [Measurement(timestamp: DateTime(2026, 3, 1, 6, 30), celsius: 36.80)],
        resolveConflict: (conflict) async {
          conflicts.add(conflict);
          return false;
        },
      );

      // Declined: the stored reading and its time stay untouched.
      final kept = controller.days.firstWhere((d) => d.date == day);
      expect(kept.temperature, 36.40);
      expect(kept.entry.temperatureAt, DateTime(2026, 3, 1, 6, 0));
      // The resolver saw both the stored and the incoming reading.
      expect(conflicts, hasLength(1));
      expect(conflicts.single.existing, 36.40);
      expect(conflicts.single.existingAt, DateTime(2026, 3, 1, 6, 0));
      expect(conflicts.single.incoming, 36.80);
      expect(conflicts.single.incomingAt, DateTime(2026, 3, 1, 6, 30));
    },
  );

  test(
    'confirming a conflict overwrites the temperature and its time',
    () async {
      final day = DateTime(2026, 3, 1);
      final controller = AppController(
        repository: InMemoryEntryRepository([
          DayEntry(
            date: day,
            temperature: 36.40,
            temperatureAt: DateTime(2026, 3, 1, 6, 0),
            menstruation: Menstruation.medium,
          ),
        ]),
        thermometer: FakeThermometerService(),
      );
      await controller.load();

      await controller.importMeasurements(
        [Measurement(timestamp: DateTime(2026, 3, 1, 6, 30), celsius: 36.80)],
        resolveConflict: (_) async => true,
      );

      final updated = controller.days.firstWhere((d) => d.date == day);
      expect(updated.temperature, 36.80);
      expect(updated.entry.temperatureAt, DateTime(2026, 3, 1, 6, 30));
      // Overwriting the temperature still keeps the logged signs.
      expect(updated.entry.menstruation, Menstruation.medium);
    },
  );

  test('the resolver is asked once per diverging day, and only those', () async {
    final controller = AppController(
      repository: InMemoryEntryRepository([
        // Diverges -> asks.
        DayEntry(date: DateTime(2026, 3, 1), temperature: 36.40),
        // Same value -> applied without asking.
        DayEntry(date: DateTime(2026, 3, 2), temperature: 36.60),
        // No stored temperature -> applied without asking.
        DayEntry(date: DateTime(2026, 3, 3), menstruation: Menstruation.light),
      ]),
      thermometer: FakeThermometerService(),
    );
    await controller.load();

    final askedDays = <DateTime>[];
    await controller.importMeasurements(
      [
        Measurement(timestamp: DateTime(2026, 3, 1, 6, 30), celsius: 36.80),
        Measurement(timestamp: DateTime(2026, 3, 2, 6, 30), celsius: 36.60),
        Measurement(timestamp: DateTime(2026, 3, 3, 6, 30), celsius: 36.70),
      ],
      resolveConflict: (conflict) async {
        askedDays.add(conflict.day);
        return true;
      },
    );

    expect(askedDays, [DateTime(2026, 3, 1)]);
    final third = controller.days.firstWhere(
      (d) => d.date == DateTime(2026, 3, 3),
    );
    expect(third.temperature, 36.70);
  });

  test('with no resolver a diverging reading is left untouched', () async {
    final day = DateTime(2026, 3, 1);
    final controller = AppController(
      repository: InMemoryEntryRepository([
        DayEntry(date: day, temperature: 36.40),
      ]),
      thermometer: FakeThermometerService(),
    );
    await controller.load();

    await controller.importMeasurements([
      Measurement(timestamp: DateTime(2026, 3, 1, 6, 30), celsius: 36.80),
    ]);

    final kept = controller.days.firstWhere((d) => d.date == day);
    expect(kept.temperature, 36.40);
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
