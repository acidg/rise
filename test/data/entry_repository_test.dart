import 'package:flutter_test/flutter_test.dart';
import 'package:rise/data/entry_repository.dart';
import 'package:rise/domain/models/day_entry.dart';

void main() {
  test(
    'editing a day updates it rather than duplicating, keyed by date',
    () async {
      final repository = InMemoryEntryRepository([
        DayEntry(date: DateTime(2026, 1, 2), temperature: 36.5),
      ]);

      await repository.save(
        DayEntry(date: DateTime(2026, 1, 1), temperature: 36.4),
      );
      // Same calendar day as the seed, different time of day: must replace it.
      await repository.save(
        DayEntry(date: DateTime(2026, 1, 2, 8, 30), temperature: 36.9),
      );

      final all = await repository.loadAll();

      expect(all.map((e) => e.date.day), [1, 2]); // chronological, no duplicate
      expect(all[1].temperature, 36.9); // replaced
    },
  );
}
