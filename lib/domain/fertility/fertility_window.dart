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

  const FertilityWindow({
    required this.firstFertileDay,
    required this.lastFertileDay,
    required this.ovulationDay,
    required this.confirmed,
    this.shiftBandStartDay,
    this.coverline,
    this.lowestHigherTemperature,
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
      lowestHigherTemperature = null;

  /// Whether [cycleDay] falls within the fertile window.
  bool isFertile(int cycleDay) =>
      cycleDay >= firstFertileDay && cycleDay <= lastFertileDay;
}
