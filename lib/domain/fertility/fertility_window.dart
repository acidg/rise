/// The computed fertile window and ovulation for one cycle, in 1-based cycle-day
/// units.
class FertilityWindow {
  /// First fertile cycle day (inclusive).
  final int firstFertileDay;

  /// Last fertile cycle day (inclusive).
  final int lastFertileDay;

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

  /// Lowest of the three higher measurements, present only when [confirmed].
  final double? lowestHigherTemperature;

  /// Whether the window rests on nothing but caution. True when neither calendar
  /// rule could be applied - no twelve documented cycles carrying a temperature
  /// shift for the "minus 8" rule, and a previous cycle that could not be
  /// evaluated for the five-day rule - and this cycle has no shift of its own
  /// either. The whole cycle is then treated as fertile, which is a fallback in
  /// the absence of data, not a finding; callers should say so rather than
  /// presenting it as an evaluated window.
  final bool unevaluated;

  const FertilityWindow({
    required this.firstFertileDay,
    required this.lastFertileDay,
    required this.ovulationDay,
    required this.confirmed,
    this.shiftBandStartDay,
    this.coverline,
    this.lowestHigherTemperature,
    this.unevaluated = false,
  });

  /// An empty window for a run with no known cycle start: nothing is fertile and
  /// there is no ovulation to mark.
  const FertilityWindow.none()
    : firstFertileDay = 1,
      lastFertileDay = 0,
      ovulationDay = 0,
      confirmed = false,
      shiftBandStartDay = null,
      coverline = null,
      lowestHigherTemperature = null,
      unevaluated = false;

  /// Whether [cycleDay] falls within the fertile window.
  bool isFertile(int cycleDay) =>
      cycleDay >= firstFertileDay && cycleDay <= lastFertileDay;
}
