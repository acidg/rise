import 'day_entry.dart';

/// A menstrual cycle: an ordered run of days that begins on the first day of
/// menstruation.
///
/// [days] is ordered oldest-first, so cycle day N is `days[N - 1]`. The newest,
/// still-open cycle has [isCurrent] set; its [length] reflects only the days
/// recorded so far, not the eventual full length.
class Cycle {
  final List<DayEntry> days;
  final bool isCurrent;

  const Cycle({required this.days, this.isCurrent = false});

  /// Date of cycle day 1.
  DateTime get startDate => days.first.date;

  /// Number of days recorded in this cycle.
  int get length => days.length;

  /// The entry for a 1-based [cycleDay].
  DayEntry dayOfCycle(int cycleDay) => days[cycleDay - 1];
}
