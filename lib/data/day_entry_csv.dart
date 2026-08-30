import '../domain/models/day_entry.dart';
import '../domain/models/signs.dart';

/// Reads and writes the day history as RFC 4180 CSV: one header row followed by
/// one row per [DayEntry], newest handling left to the caller.
///
/// This is the portable, user-inspectable form of the history (openable in any
/// spreadsheet). Only user-entered tracking data is represented; the paired
/// thermometer is device-specific and deliberately absent. Enums are written by
/// their [Enum.name] so the file stays readable and stable across releases, and
/// unknown or empty values decode back to the field default, matching
/// [DayEntry.fromJson].
class DayEntryCsv {
  /// Column order of the CSV, also the header row. Decoding looks columns up by
  /// name, so a file whose columns were reordered still imports.
  static const List<String> columns = [
    'date',
    'temperature',
    'temperatureAt',
    'menstruation',
    'mucus',
    'cervix',
    'pain',
    'mood',
    'libido',
    'intercourse',
    'notes',
  ];

  const DayEntryCsv._();

  /// Encode [entries] to a CSV document with a header row. Entries are emitted in
  /// the order given; the caller sorts.
  static String encode(List<DayEntry> entries) {
    final buffer = StringBuffer()..writeln(_row(columns));
    for (final entry in entries) {
      buffer.writeln(_row(_cells(entry)));
    }
    return buffer.toString();
  }

  /// Parse a CSV document produced by [encode] (or an equivalent spreadsheet
  /// export) back into entries. The header row names the columns, so column order
  /// is free; any column may be omitted and decodes to the field default.
  ///
  /// Throws [FormatException] when the header is missing or a row has no valid
  /// `date`, since an entry cannot be keyed without its day. Unknown enum values
  /// and unparseable temperatures fall back to the default rather than failing,
  /// so a slightly malformed cell never loses the rest of the row.
  static List<DayEntry> decode(String csv) {
    final rows = _parse(csv);
    if (rows.isEmpty) {
      return const [];
    }
    final header = rows.first;
    final index = <String, int>{};
    for (var i = 0; i < header.length; i++) {
      index[header[i].trim()] = i;
    }
    if (!index.containsKey('date')) {
      throw const FormatException('CSV is missing the required "date" column.');
    }
    final entries = <DayEntry>[];
    for (var r = 1; r < rows.length; r++) {
      final row = rows[r];
      if (_isBlank(row)) {
        continue;
      }
      entries.add(_entry(row, index, r + 1));
    }
    return entries;
  }

  static List<String> _cells(DayEntry entry) {
    return [
      _date(entry.date),
      entry.temperature?.toString() ?? '',
      entry.temperatureAt == null ? '' : _dateTime(entry.temperatureAt!),
      entry.menstruation.name,
      entry.mucus.name,
      entry.cervix?.name ?? '',
      entry.pain.name,
      entry.mood?.name ?? '',
      entry.libido.name,
      entry.intercourse.name,
      entry.notes,
    ];
  }

  static DayEntry _entry(List<String> row, Map<String, int> index, int lineNo) {
    String? cell(String name) {
      final i = index[name];
      if (i == null || i >= row.length) {
        return null;
      }
      final value = row[i].trim();
      return value.isEmpty ? null : value;
    }

    final rawDate = cell('date');
    final date = rawDate == null ? null : DateTime.tryParse(rawDate);
    if (date == null) {
      throw FormatException('Row $lineNo has no valid date ("${rawDate ?? ''}").');
    }
    final rawTemperatureAt = cell('temperatureAt');
    return DayEntry(
      date: DateTime(date.year, date.month, date.day),
      temperature: double.tryParse(cell('temperature') ?? ''),
      temperatureAt:
          rawTemperatureAt == null ? null : DateTime.tryParse(rawTemperatureAt),
      menstruation:
          _enumByName(Menstruation.values, cell('menstruation')) ??
          Menstruation.none,
      mucus:
          _enumByName(CervicalMucus.values, cell('mucus')) ?? CervicalMucus.none,
      cervix: _enumByName(Cervix.values, cell('cervix')),
      pain: _enumByName(Pain.values, cell('pain')) ?? Pain.none,
      mood: _enumByName(Mood.values, cell('mood')),
      libido: _enumByName(Libido.values, cell('libido')) ?? Libido.none,
      intercourse:
          _enumByName(Intercourse.values, cell('intercourse')) ??
          Intercourse.none,
      notes: cell('notes') ?? '',
    );
  }

  static T? _enumByName<T extends Enum>(List<T> values, String? name) {
    if (name == null) {
      return null;
    }
    for (final value in values) {
      if (value.name == name) {
        return value;
      }
    }
    return null;
  }

  static String _date(DateTime date) =>
      '${_pad(date.year, 4)}-${_pad(date.month, 2)}-${_pad(date.day, 2)}';

  static String _dateTime(DateTime at) =>
      '${_date(at)}T${_pad(at.hour, 2)}:${_pad(at.minute, 2)}:${_pad(at.second, 2)}';

  static String _pad(int value, int width) =>
      value.toString().padLeft(width, '0');

  /// Join [cells] into one CSV line, quoting any cell that contains a comma,
  /// quote, or line break and doubling embedded quotes, per RFC 4180.
  static String _row(List<String> cells) => cells.map(_escape).join(',');

  static String _escape(String cell) {
    if (!cell.contains(RegExp('[",\r\n]'))) {
      return cell;
    }
    return '"${cell.replaceAll('"', '""')}"';
  }

  static bool _isBlank(List<String> row) =>
      row.every((cell) => cell.trim().isEmpty);

  /// Tokenise a CSV document into rows of cells, honouring quoted fields that may
  /// contain commas, escaped quotes, and line breaks. Accepts both `\n` and
  /// `\r\n` line endings.
  static List<List<String>> _parse(String csv) {
    final rows = <List<String>>[];
    var row = <String>[];
    final cell = StringBuffer();
    var inQuotes = false;
    var sawContent = false;

    void endCell() {
      row.add(cell.toString());
      cell.clear();
    }

    void endRow() {
      endCell();
      rows.add(row);
      row = <String>[];
      sawContent = false;
    }

    for (var i = 0; i < csv.length; i++) {
      final char = csv[i];
      if (inQuotes) {
        if (char == '"') {
          if (i + 1 < csv.length && csv[i + 1] == '"') {
            cell.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          cell.write(char);
        }
        continue;
      }
      switch (char) {
        case '"':
          inQuotes = true;
          sawContent = true;
        case ',':
          sawContent = true;
          endCell();
        case '\r':
          break;
        case '\n':
          endRow();
        default:
          sawContent = true;
          cell.write(char);
      }
    }
    // Flush a trailing row that had no final newline.
    if (sawContent || cell.isNotEmpty || row.isNotEmpty) {
      endRow();
    }
    return rows;
  }
}
