import 'signs.dart';

/// Look up an enum member by its [Enum.name], returning null when the stored
/// value is absent or no longer maps to a known member.
T? _enumByName<T extends Enum>(List<T> values, Object? name) {
  if (name is! String) {
    return null;
  }
  for (final value in values) {
    if (value.name == name) {
      return value;
    }
  }
  return null;
}

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

  /// Serialise to a JSON-compatible map. Enums are stored by name so the wire
  /// form stays stable and readable if their declaration order ever changes.
  /// The date is normalised to its calendar day, matching how entries are keyed.
  Map<String, dynamic> toJson() {
    return {
      'date': DateTime(date.year, date.month, date.day).toIso8601String(),
      'temperature': temperature,
      'menstruation': menstruation.name,
      'mucus': mucus.name,
      'cervix': cervix?.name,
      'pain': pain.name,
      'mood': mood?.name,
      'libido': libido.name,
      'intercourse': intercourse.name,
      'notes': notes,
    };
  }

  /// Rebuild an entry from [toJson]. Unknown or missing enum values fall back to
  /// the field default, so an older stored history stays readable after the enums
  /// gain new members.
  factory DayEntry.fromJson(Map<String, dynamic> json) {
    return DayEntry(
      date: DateTime.parse(json['date'] as String),
      temperature: (json['temperature'] as num?)?.toDouble(),
      menstruation:
          _enumByName(Menstruation.values, json['menstruation']) ??
          Menstruation.none,
      mucus:
          _enumByName(CervicalMucus.values, json['mucus']) ??
          CervicalMucus.none,
      cervix: _enumByName(Cervix.values, json['cervix']),
      pain: _enumByName(Pain.values, json['pain']) ?? Pain.none,
      mood: _enumByName(Mood.values, json['mood']),
      libido: _enumByName(Libido.values, json['libido']) ?? Libido.none,
      intercourse:
          _enumByName(Intercourse.values, json['intercourse']) ??
          Intercourse.none,
      notes: json['notes'] as String? ?? '',
    );
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
