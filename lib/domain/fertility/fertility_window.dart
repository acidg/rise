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

  /// Coverline temperature, present only when [confirmed].
  final double? coverline;

  /// Lowest of the three higher measurements, present only when [confirmed].
  final double? lowestHigherTemperature;

  const FertilityWindow({
    required this.firstFertileDay,
    required this.lastFertileDay,
    required this.ovulationDay,
    required this.confirmed,
    this.coverline,
    this.lowestHigherTemperature,
  });

  /// Whether [cycleDay] falls within the fertile window.
  bool isFertile(int cycleDay) =>
      cycleDay >= firstFertileDay && cycleDay <= lastFertileDay;
}
