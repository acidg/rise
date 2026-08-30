import 'package:flutter_test/flutter_test.dart';
import 'package:rise/data/shared_preferences_entry_repository.dart';
import 'package:rise/domain/models/day_entry.dart';
import 'package:rise/domain/models/signs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('an empty store loads no entries', () async {
    final repository = SharedPreferencesEntryRepository();
    expect(await repository.loadAll(), isEmpty);
  });

  test('saved entries survive a fresh repository instance', () async {
    await SharedPreferencesEntryRepository().save(
      DayEntry(
        date: DateTime(2026, 5, 4),
        temperature: 36.62,
        temperatureAt: DateTime(2026, 5, 4, 6, 45),
        menstruation: Menstruation.medium,
        mucus: CervicalMucus.eggWhite,
        cervix: Cervix.highSoft,
        pain: Pain.mild,
        mood: Mood.great,
        libido: Libido.high,
        intercourse: Intercourse.unprotectedSex,
        notes: 'positive OPK',
      ),
    );

    // A new instance shares only the persisted bytes, so a correct round-trip
    // reproduces every field.
    final loaded = await SharedPreferencesEntryRepository().loadAll();

    expect(loaded, hasLength(1));
    final entry = loaded.single;
    expect(entry.date, DateTime(2026, 5, 4));
    expect(entry.temperature, 36.62);
    expect(entry.temperatureAt, DateTime(2026, 5, 4, 6, 45));
    expect(entry.menstruation, Menstruation.medium);
    expect(entry.mucus, CervicalMucus.eggWhite);
    expect(entry.cervix, Cervix.highSoft);
    expect(entry.pain, Pain.mild);
    expect(entry.mood, Mood.great);
    expect(entry.libido, Libido.high);
    expect(entry.intercourse, Intercourse.unprotectedSex);
    expect(entry.notes, 'positive OPK');
  });

  test('nullable signs round-trip as null', () async {
    await SharedPreferencesEntryRepository().save(
      DayEntry(date: DateTime(2026, 5, 4), temperature: 36.5),
    );

    final entry = (await SharedPreferencesEntryRepository().loadAll()).single;

    expect(entry.cervix, isNull);
    expect(entry.mood, isNull);
    expect(entry.temperatureAt, isNull);
  });

  test('re-saving a day replaces it, keyed by calendar date', () async {
    final repository = SharedPreferencesEntryRepository();
    await repository.save(
      DayEntry(date: DateTime(2026, 5, 4), temperature: 36.40),
    );
    // Same calendar day, different time of day: must replace, not duplicate.
    await repository.save(
      DayEntry(date: DateTime(2026, 5, 4, 7, 15), temperature: 36.90),
    );

    final all = await repository.loadAll();

    expect(all, hasLength(1));
    expect(all.single.temperature, 36.90);
  });

  test('entries load oldest-first', () async {
    final repository = SharedPreferencesEntryRepository();
    await repository.save(DayEntry(date: DateTime(2026, 5, 6)));
    await repository.save(DayEntry(date: DateTime(2026, 5, 4)));
    await repository.save(DayEntry(date: DateTime(2026, 5, 5)));

    final days = (await repository.loadAll()).map((e) => e.date.day).toList();

    expect(days, [4, 5, 6]);
  });
}
