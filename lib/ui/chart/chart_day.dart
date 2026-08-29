import '../../domain/models/day_entry.dart';

/// A single day prepared for the chart: the logged [entry] plus the derived
/// cycle and fertility facts the chart needs to draw it.
class ChartDay {
  final DayEntry entry;
  final int cycleDay;
  final bool fertile;
  final bool isOvulation;

  /// Whether ovulation is confirmed for this day's cycle.
  final bool confirmed;

  /// Coverline (highest of the six low measurements) for this day, present only
  /// on the shift band of a confirmed cycle.
  final double? coverline;

  /// Lowest of the three higher measurements for this day, present only on the
  /// shift band of a confirmed cycle. Drawn as the upper reference line.
  final double? lowestHigherTemperature;

  /// A predicted day past today, with no logged data. Not tappable.
  final bool isFuture;

  /// The most recent recorded day of the current cycle.
  final bool isToday;

  const ChartDay({
    required this.entry,
    required this.cycleDay,
    required this.fertile,
    required this.isOvulation,
    required this.confirmed,
    required this.coverline,
    required this.lowestHigherTemperature,
    this.isFuture = false,
    this.isToday = false,
  });

  DateTime get date => entry.date;
  double? get temperature => entry.temperature;
  bool get hasEntry => entry.hasUserEntry;
}
