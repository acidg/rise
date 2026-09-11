import '../../domain/models/day_entry.dart';

/// A single day prepared for the chart: the logged [entry] plus the derived
/// cycle and fertility facts the chart needs to draw it.
class ChartDay {
  final DayEntry entry;

  /// 1-based cycle day, or null when the day belongs to a run with no known
  /// cycle start (rendered as "?").
  final int? cycleDay;
  final bool fertile;
  final bool isOvulation;

  /// Whether ovulation is confirmed for this day's cycle.
  final bool confirmed;

  /// Whether this day's window rests on no evaluation, so a fertile day is a
  /// precaution rather than a finding and is drawn neutrally.
  final bool unevaluated;

  /// Coverline (highest of the six low measurements) for this day, present only
  /// on the shift band of a confirmed cycle.
  final double? coverline;

  /// Lowest of the three higher measurements for this day, present only on the
  /// shift band of a confirmed cycle. Drawn as the upper reference line.
  final double? lowestHigherTemperature;

  /// A predicted day past today, with no logged data. Not tappable.
  final bool isFuture;

  /// The current calendar day. Always present on the chart, whether or not
  /// anything was logged for it.
  final bool isToday;

  const ChartDay({
    required this.entry,
    required this.cycleDay,
    required this.fertile,
    required this.isOvulation,
    required this.confirmed,
    this.unevaluated = false,
    required this.coverline,
    required this.lowestHigherTemperature,
    this.isFuture = false,
    this.isToday = false,
  });

  DateTime get date => entry.date;
  double? get temperature => entry.temperature;

  /// Whether the measurement is excluded from the rules, and so drawn as a
  /// disturbed value the curve steps over.
  bool get temperatureExcluded => entry.temperatureExcluded;
  bool get hasEntry => entry.hasUserEntry;
}
