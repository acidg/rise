import 'signs.dart';

/// One day's logged data, keyed by its calendar [date].
///
/// This is the raw record as measured or entered by the user; cycle grouping and
/// fertility flags are derived elsewhere and never stored here. [date] is
/// expected to be normalised to local midnight so it identifies a day.
/// [temperature] is the basal body temperature in degrees Celsius, or null when
/// no measurement exists for the day.
class DayEntry {
  final DateTime date;
  final double? temperature;
  final Menstruation menstruation;
  final CervicalMucus mucus;
  final Cervix? cervix;
  final Pain pain;
  final Mood? mood;
  final Libido libido;
  final Intercourse intercourse;
  final String notes;

  const DayEntry({
    required this.date,
    this.temperature,
    this.menstruation = Menstruation.none,
    this.mucus = CervicalMucus.none,
    this.cervix,
    this.pain = Pain.none,
    this.mood,
    this.libido = Libido.none,
    this.intercourse = Intercourse.none,
    this.notes = '',
  });

  /// Whether the user logged anything beyond an auto-synced temperature. Drives
  /// the "has entry" indicator on the chart.
  bool get hasUserEntry {
    return notes.isNotEmpty ||
        intercourse != Intercourse.none ||
        menstruation != Menstruation.none ||
        mucus.isPresent ||
        pain != Pain.none;
  }

  DayEntry copyWith({
    double? temperature,
    Menstruation? menstruation,
    CervicalMucus? mucus,
    Cervix? cervix,
    Pain? pain,
    Mood? mood,
    Libido? libido,
    Intercourse? intercourse,
    String? notes,
  }) {
    return DayEntry(
      date: date,
      temperature: temperature ?? this.temperature,
      menstruation: menstruation ?? this.menstruation,
      mucus: mucus ?? this.mucus,
      cervix: cervix ?? this.cervix,
      pain: pain ?? this.pain,
      mood: mood ?? this.mood,
      libido: libido ?? this.libido,
      intercourse: intercourse ?? this.intercourse,
      notes: notes ?? this.notes,
    );
  }
}
