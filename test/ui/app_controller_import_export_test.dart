import 'package:flutter_test/flutter_test.dart';
import 'package:rise/ble/thermometer_service.dart';
import 'package:rise/data/entry_repository.dart';
import 'package:rise/data/paired_device_store.dart';
import 'package:rise/domain/models/day_entry.dart';
import 'package:rise/domain/models/signs.dart';
import 'package:rise/ui/app_controller.dart';

AppController _controller(List<DayEntry> seed) => AppController(
  repository: InMemoryEntryRepository(seed),
  thermometer: FakeThermometerService(),
);

void main() {
  test(
    'exported CSV round-trips through import into a fresh history',
    () async {
      final entries = [
        DayEntry(
          date: DateTime(2026, 3, 1),
          temperature: 36.40,
          menstruation: Menstruation.medium,
          notes: 'day, one',
        ),
        DayEntry(date: DateTime(2026, 3, 2), temperature: 36.55),
      ];
      final source = _controller(entries);
      await source.load();
      final csv = await source.exportCsv();

      final target = _controller(const []);
      await target.load();
      final result = await target.importCsv(csv);

      expect(result.added, 2);
      expect(
        target.days.map((d) => d.temperature),
        containsAll([36.40, 36.55]),
      );
      expect(
        target.days
            .firstWhere((d) => d.date == DateTime(2026, 3, 1))
            .entry
            .notes,
        'day, one',
      );
    },
  );

  test('an unchanged day is skipped, not counted as replaced', () async {
    final entry = DayEntry(date: DateTime(2026, 3, 1), temperature: 36.40);
    final controller = _controller([entry]);
    await controller.load();
    final csv = await controller.exportCsv();

    final result = await controller.importCsv(csv);

    expect(result, isA<ImportResult>());
    expect(result.added, 0);
    expect(result.replaced, 0);
    expect(result.skipped, 1);
  });

  test('a differing day is replaced only when the resolver agrees', () async {
    final controller = _controller([
      DayEntry(date: DateTime(2026, 3, 1), temperature: 36.40),
      DayEntry(date: DateTime(2026, 3, 2), temperature: 36.50),
    ]);
    await controller.load();
    // A file that changes both days.
    const csv =
        'date,temperature\n'
        '2026-03-01,36.90\n'
        '2026-03-02,36.95\n';

    // Approve only the first conflict.
    var seen = 0;
    final result = await controller.importCsv(
      csv,
      resolveConflict: (conflict) async {
        seen++;
        return conflict.day == DateTime(2026, 3, 1);
      },
    );

    expect(seen, 2);
    expect(result.replaced, 1);
    expect(result.skipped, 1);
    expect(
      controller.days
          .firstWhere((d) => d.date == DateTime(2026, 3, 1))
          .temperature,
      36.90,
    );
    // The rejected conflict keeps its stored value.
    expect(
      controller.days
          .firstWhere((d) => d.date == DateTime(2026, 3, 2))
          .temperature,
      36.50,
    );
  });

  test(
    'without a resolver a differing day is kept, never overwritten',
    () async {
      final controller = _controller([
        DayEntry(date: DateTime(2026, 3, 1), temperature: 36.40),
      ]);
      await controller.load();

      final result = await controller.importCsv(
        'date,temperature\n2026-03-01,36.90\n',
      );

      expect(result.skipped, 1);
      expect(
        controller.days
            .firstWhere((d) => d.date == DateTime(2026, 3, 1))
            .temperature,
        36.40,
      );
    },
  );

  test('the paired thermometer is not part of the exported data', () async {
    final controller = AppController(
      repository: InMemoryEntryRepository([
        DayEntry(date: DateTime(2026, 3, 1), temperature: 36.40),
      ]),
      thermometer: FakeThermometerService(),
      pairedDeviceStore: InMemoryPairedDeviceStore(
        const DiscoveredThermometer(id: 'AA:BB:CC', name: 'Ovy OT35'),
      ),
    );
    await controller.load();

    final csv = await controller.exportCsv();

    expect(csv, isNot(contains('AA:BB:CC')));
    expect(csv, isNot(contains('Ovy OT35')));
  });
}
