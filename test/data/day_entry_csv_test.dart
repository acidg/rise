import 'package:flutter_test/flutter_test.dart';
import 'package:rise/data/day_entry_csv.dart';
import 'package:rise/domain/models/day_entry.dart';
import 'package:rise/domain/models/signs.dart';

void main() {
  test('a fully populated entry survives an encode/decode round-trip', () {
    final entry = DayEntry(
      date: DateTime(2026, 5, 4),
      temperature: 36.62,
      temperatureAt: DateTime(2026, 5, 4, 6, 45, 30),
      menstruation: Menstruation.medium,
      mucus: CervicalMucus.eggWhite,
      cervix: Cervix.highSoft,
      pain: Pain.mild,
      mood: Mood.great,
      libido: Libido.high,
      intercourse: Intercourse.unprotectedSex,
      notes: 'positive OPK',
    );

    final decoded = DayEntryCsv.decode(DayEntryCsv.encode([entry]));

    expect(decoded.single, entry);
    expect(decoded.single.temperatureAt, DateTime(2026, 5, 4, 6, 45, 30));
  });

  test('nullable fields encode as empty cells and decode back to null', () {
    final entry = DayEntry(date: DateTime(2026, 5, 4), temperature: 36.5);

    final decoded = DayEntryCsv.decode(DayEntryCsv.encode([entry])).single;

    expect(decoded.temperatureAt, isNull);
    expect(decoded.cervix, isNull);
    expect(decoded.mood, isNull);
    expect(decoded, entry);
  });

  test('notes with commas, quotes, and newlines round-trip intact', () {
    final entry = DayEntry(
      date: DateTime(2026, 5, 4),
      notes: 'woke late, "restless"\nsecond line',
    );

    final csv = DayEntryCsv.encode([entry]);
    // The tricky cell must be quoted with the quote doubled.
    expect(csv, contains('"woke late, ""restless""'));
    expect(DayEntryCsv.decode(csv).single, entry);
  });

  test('the header row lists the columns in order', () {
    final csv = DayEntryCsv.encode(const []);
    expect(csv.trim(), DayEntryCsv.columns.join(','));
  });

  test('columns may be reordered and omitted, decoding to defaults', () {
    const csv =
        'notes,date\n'
        'hello,2026-05-04\n';

    final entry = DayEntryCsv.decode(csv).single;

    expect(entry.date, DateTime(2026, 5, 4));
    expect(entry.notes, 'hello');
    // Omitted columns fall back to the field defaults.
    expect(entry.menstruation, Menstruation.none);
    expect(entry.mucus, CervicalMucus.none);
    expect(entry.temperature, isNull);
  });

  test('an unknown enum value falls back to the default', () {
    const csv =
        'date,mucus\n'
        '2026-05-04,fromMars\n';

    expect(DayEntryCsv.decode(csv).single.mucus, CervicalMucus.none);
  });

  test('a blank line between rows is ignored', () {
    const csv =
        'date\n'
        '2026-05-04\n'
        '\n'
        '2026-05-05\n';

    expect(DayEntryCsv.decode(csv), hasLength(2));
  });

  test('CRLF line endings are accepted', () {
    const csv = 'date,notes\r\n2026-05-04,hi\r\n';

    final entry = DayEntryCsv.decode(csv).single;
    expect(entry.date, DateTime(2026, 5, 4));
    expect(entry.notes, 'hi');
  });

  test('an empty document decodes to no entries', () {
    expect(DayEntryCsv.decode(''), isEmpty);
  });

  test('a missing date column is rejected', () {
    expect(
      () => DayEntryCsv.decode('temperature\n36.5\n'),
      throwsFormatException,
    );
  });

  test('a row with an unparseable date is rejected', () {
    expect(
      () => DayEntryCsv.decode('date\nnot-a-date\n'),
      throwsFormatException,
    );
  });

  test('the date is normalised to its calendar day', () {
    // A time-of-day on the date cell must not leak into the key.
    final entry = DayEntryCsv.decode('date\n2026-05-04T09:30:00\n').single;
    expect(entry.date, DateTime(2026, 5, 4));
  });
}
