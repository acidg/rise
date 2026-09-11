/// Which rule set the earliest day the fertile window could open.
enum CalendarRule {
  /// The "minus 8" rule, from the earliest first higher measurement of the most
  /// recent twelve documented cycles.
  minusEight,

  /// The five-day rule, which frees days one to five after a cycle whose
  /// temperature could be evaluated.
  fiveDay,

  /// Neither could be applied - too few documented cycles for "minus 8" and a
  /// previous cycle that could not be evaluated - so the window opens on day one
  /// out of caution.
  none,
}

/// The computed fertile window and ovulation for one cycle, in 1-based cycle-day
/// units.
class FertilityWindow {
  /// First fertile cycle day (inclusive).
  final int firstFertileDay;

  /// Last fertile cycle day (inclusive) once the window has an end. While [open]
  /// it is the day the window is predicted to close, used to decide how far
  /// ahead to draw, not a bound on fertility.
  final int lastFertileDay;

  /// The rule that produced [calendarStartDay].
  final CalendarRule calendarRule;

  /// The earliest day the calendar rules allow, before mucus onset may have
  /// opened the window earlier. Equal to [firstFertileDay] unless mucus was
  /// logged before it.
  final int calendarStartDay;

  /// Whether the window is still open, with no day yet ending it. True whenever
  /// no temperature shift has been confirmed: only the shift closes the fertile
  /// phase under the symptothermal method, so until one is evaluated every day
  /// from [firstFertileDay] on counts as fertile, however late in the cycle.
  final bool open;

  /// Estimated ovulation cycle day.
  final int ovulationDay;

  /// Whether the temperature shift has confirmed ovulation. When false the
  /// window is a prediction and stays open.
  final bool confirmed;

  /// First cycle day the coverline and upper reference line are drawn from - the
  /// earliest of the six low measurements. Present only when [confirmed].
  final int? shiftBandStartDay;

  /// Coverline temperature, present only when [confirmed].
  final double? coverline;

  /// The measurement that completed the temperature evaluation, the day the
  /// shift closed the fertile window. Present only when [confirmed].
  final double? confirmingTemperature;

  const FertilityWindow({
    required this.firstFertileDay,
    required this.lastFertileDay,
    required this.ovulationDay,
    required this.confirmed,
    this.open = false,
    this.calendarRule = CalendarRule.fiveDay,
    int? calendarStartDay,
    this.shiftBandStartDay,
    this.coverline,
    this.confirmingTemperature,
  }) : calendarStartDay = calendarStartDay ?? firstFertileDay;

  /// Whether the window rests on nothing but caution: neither calendar rule
  /// could be applied, so the whole cycle is treated as fertile. That is a
  /// fallback in the absence of data, not a finding, and callers should say so
  /// rather than present it as an evaluated window.
  bool get unevaluated => calendarRule == CalendarRule.none && !confirmed;

  /// An empty window for a run with no known cycle start: nothing is fertile and
  /// there is no ovulation to mark.
  const FertilityWindow.none()
    : firstFertileDay = 1,
      lastFertileDay = 0,
      ovulationDay = 0,
      confirmed = false,
      open = false,
      calendarRule = CalendarRule.fiveDay,
      calendarStartDay = 1,
      shiftBandStartDay = null,
      coverline = null,
      confirmingTemperature = null;

  /// Whether [cycleDay] falls within the fertile window. An [open] window has no
  /// upper bound: nothing has closed it, so every day from [firstFertileDay] on
  /// is fertile.
  bool isFertile(int cycleDay) =>
      cycleDay >= firstFertileDay && (open || cycleDay <= lastFertileDay);
}
