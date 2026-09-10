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
/// no measurement exists for the day. [temperatureAt] is the moment that
/// temperature was taken, filled from the thermometer's clock on sync or entered
/// by hand; null when unknown.
///
/// A measurement taken under a known disturbance (illness, alcohol, an unusual
/// waking time) stays recorded but must not drive the rules. The two exclusion
/// flags express that: they keep the value visible on the chart while hiding it
/// from the analysis, which reads [temperatureForAnalysis] and
/// [menstruationForAnalysis] instead of the raw fields.
class DayEntry {
  final DateTime date;
  final double? temperature;
  final DateTime? temperatureAt;
  final bool temperatureExcluded;
  final Menstruation menstruation;
  final bool menstruationExcluded;
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
    this.temperatureAt,
    this.temperatureExcluded = false,
    this.menstruation = Menstruation.none,
    this.menstruationExcluded = false,
    this.mucus = CervicalMucus.none,
    this.cervix,
    this.pain = Pain.none,
    this.mood,
    this.libido = Libido.none,
    this.intercourse = Intercourse.none,
    this.notes = '',
  });

  /// Whether the user logged anything beyond an auto-synced temperature. Drives
  /// the "has entry" indicator on the chart. Excluding a value counts: it is a
  /// deliberate entry about the day, even on a day that holds nothing else.
  bool get hasUserEntry {
    return notes.isNotEmpty ||
        intercourse != Intercourse.none ||
        menstruation != Menstruation.none ||
        mucus.isPresent ||
        pain != Pain.none ||
        temperatureExcluded ||
        menstruationExcluded;
  }

  /// The temperature the fertility rules may use: null when the day carries no
  /// measurement or the one it carries is excluded, so a disturbed value counts
  /// as a measurement gap rather than a low or a higher measurement.
  double? get temperatureForAnalysis =>
      temperatureExcluded ? null : temperature;

  /// The bleeding the cycle rules may use: [Menstruation.none] when the logged
  /// bleeding is excluded, so a withdrawal or breakthrough bleed does not start
  /// a new cycle.
  Menstruation get menstruationForAnalysis =>
      menstruationExcluded ? Menstruation.none : menstruation;

  /// Serialise to a JSON-compatible map. Enums are stored by name so the wire
  /// form stays stable and readable if their declaration order ever changes.
  /// The date is normalised to its calendar day, matching how entries are keyed.
  Map<String, dynamic> toJson() {
    return {
      'date': DateTime(date.year, date.month, date.day).toIso8601String(),
      'temperature': temperature,
      'temperatureAt': temperatureAt?.toIso8601String(),
      'temperatureExcluded': temperatureExcluded,
      'menstruation': menstruation.name,
      'menstruationExcluded': menstruationExcluded,
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
      temperatureAt: switch (json['temperatureAt']) {
        final String at => DateTime.parse(at),
        _ => null,
      },
      temperatureExcluded: json['temperatureExcluded'] as bool? ?? false,
      menstruation:
          _enumByName(Menstruation.values, json['menstruation']) ??
          Menstruation.none,
      menstruationExcluded: json['menstruationExcluded'] as bool? ?? false,
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

  /// Value equality over every logged field, so two entries loaded for the same
  /// day compare equal when their contents match. Used by import to tell an
  /// unchanged day from a genuine conflict. [date] is compared by calendar day,
  /// matching how entries are keyed.
  @override
  bool operator ==(Object other) {
    return other is DayEntry &&
        _dateKey(other.date) == _dateKey(date) &&
        other.temperature == temperature &&
        other.temperatureAt == temperatureAt &&
        other.temperatureExcluded == temperatureExcluded &&
        other.menstruation == menstruation &&
        other.menstruationExcluded == menstruationExcluded &&
        other.mucus == mucus &&
        other.cervix == cervix &&
        other.pain == pain &&
        other.mood == mood &&
        other.libido == libido &&
        other.intercourse == intercourse &&
        other.notes == notes;
  }

  @override
  int get hashCode => Object.hash(
    _dateKey(date),
    temperature,
    temperatureAt,
    temperatureExcluded,
    menstruation,
    menstruationExcluded,
    mucus,
    cervix,
    pain,
    mood,
    libido,
    intercourse,
    notes,
  );

  static DateTime _dateKey(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  DayEntry copyWith({
    double? temperature,
    DateTime? temperatureAt,
    bool? temperatureExcluded,
    Menstruation? menstruation,
    bool? menstruationExcluded,
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
      temperatureAt: temperatureAt ?? this.temperatureAt,
      temperatureExcluded: temperatureExcluded ?? this.temperatureExcluded,
      menstruation: menstruation ?? this.menstruation,
      menstruationExcluded: menstruationExcluded ?? this.menstruationExcluded,
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
