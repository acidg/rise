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

  /// Coverline temperature for this day's cycle, or null when not confirmed.
  final double? coverline;

  const ChartDay({
    required this.entry,
    required this.cycleDay,
    required this.fertile,
    required this.isOvulation,
    required this.confirmed,
    required this.coverline,
  });

  DateTime get date => entry.date;
  double? get temperature => entry.temperature;
  bool get hasEntry => entry.hasUserEntry;
}
