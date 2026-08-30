import 'day_entry.dart';

/// A menstrual cycle: an ordered run of days that begins on the first day of
/// menstruation.
///
/// [days] is ordered oldest-first, so cycle day N is `days[N - 1]`. The newest,
/// still-open cycle has [isCurrent] set; its [length] reflects only the days
/// recorded so far, not the eventual full length.
///
/// [hasKnownStart] is false when the run does not begin on a bleeding onset, for
/// example the leading stretch of a history that started mid-cycle, or a record
/// with no bleeding logged at all. Such a run has no meaningful cycle-day
/// numbering and no fertile window: cycle day is shown as "?".
class Cycle {
  final List<DayEntry> days;
  final bool isCurrent;
  final bool hasKnownStart;

  const Cycle({
    required this.days,
    this.isCurrent = false,
    this.hasKnownStart = true,
  });

  /// Date of cycle day 1.
  DateTime get startDate => days.first.date;

  /// Number of days recorded in this cycle.
  int get length => days.length;

  /// The entry for a 1-based [cycleDay].
  DayEntry dayOfCycle(int cycleDay) => days[cycleDay - 1];
}
