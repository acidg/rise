import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/day_entry.dart';
import 'entry_repository.dart';

/// [EntryRepository] backed by `shared_preferences`, persisting the whole day
/// history as a single JSON array so it survives app restarts.
///
/// A stepping stone toward an encrypted local database and end-to-end encrypted
/// sync; because it sits behind [EntryRepository], that later swap does not touch
/// the UI. Entries are keyed by calendar date, so re-saving a day replaces it.
class SharedPreferencesEntryRepository implements EntryRepository {
  static const String _key = 'day_entries';

  @override
  Future<List<DayEntry>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    return _read(prefs).values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  @override
  Future<void> save(DayEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final byDate = _read(prefs);
    byDate[_dateKey(entry.date)] = entry;
    final ordered = byDate.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    await prefs.setString(
      _key,
      jsonEncode([for (final e in ordered) e.toJson()]),
    );
  }

  /// Decode the stored history into a date-keyed map. Returns empty when nothing
  /// has been saved yet.
  Map<DateTime, DayEntry> _read(SharedPreferences prefs) {
    final raw = prefs.getString(_key);
    if (raw == null) {
      return {};
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return {
      for (final item in decoded)
        _dateKey(
          DateTime.parse((item as Map<String, dynamic>)['date'] as String),
        ): DayEntry.fromJson(
          item,
        ),
    };
  }

  static DateTime _dateKey(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
