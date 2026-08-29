import '../domain/models/day_entry.dart';

/// Stores the day entries that make up the user's history.
///
/// An interface so the app can start on an in-memory store and later move to an
/// encrypted local database and end-to-end encrypted sync without touching the
/// UI. Entries are keyed by calendar date.
abstract interface class EntryRepository {
  /// All entries, ordered oldest-first.
  Future<List<DayEntry>> loadAll();

  /// Insert or replace the entry for its calendar date (the time of day is
  /// ignored), so editing a day updates it rather than duplicating it.
  Future<void> save(DayEntry entry);
}

/// Non-persistent [EntryRepository] backing the demo build and tests.
class InMemoryEntryRepository implements EntryRepository {
  final Map<DateTime, DayEntry> _byDate = {};

  InMemoryEntryRepository([List<DayEntry> seed = const []]) {
    for (final entry in seed) {
      _byDate[_dateKey(entry.date)] = entry;
    }
  }

  @override
  Future<List<DayEntry>> loadAll() async {
    final entries = _byDate.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return entries;
  }

  @override
  Future<void> save(DayEntry entry) async {
    _byDate[_dateKey(entry.date)] = entry;
  }

  static DateTime _dateKey(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
