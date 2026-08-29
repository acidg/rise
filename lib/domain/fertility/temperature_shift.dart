import 'dart:math';

/// The third higher measurement must exceed the coverline by at least this many
/// degrees Celsius for a same-day confirmation.
const double kShiftMinimumRise = 0.2;

/// Result of the Sensiplan temperature-shift evaluation for one cycle. All day
/// values are 1-based cycle days.
class TemperatureShift {
  /// Ovulation cycle day: the day before the first higher measurement (the last
  /// of the low measurements).
  final int ovulationDay;

  /// Cycle day on which the shift is confirmed and the temperature closes the
  /// fertile window (the third higher measurement, or the fourth under the
  /// exception).
  final int confirmationDay;

  /// Highest of the six low measurements before the rise (the coverline).
  final double coverline;

  /// Lowest of the three higher measurements that confirm the shift.
  final double lowestHigherTemperature;

  const TemperatureShift({
    required this.ovulationDay,
    required this.confirmationDay,
    required this.coverline,
    required this.lowestHigherTemperature,
  });
}

/// Detect the temperature shift in a cycle's ordered daily temperatures.
///
/// [temperatures] is indexed by cycle day minus one (`temperatures[0]` is cycle
/// day 1). Missing measurements are null and never satisfy the rule. Returns
/// null when no valid shift is present (an anovulatory cycle, or too little
/// data).
///
/// Rule (Sensiplan "three over six"): find three consecutive measurements above
/// the coverline - the highest of the preceding six low measurements. The shift
/// confirms on the third higher measurement when it clears the coverline by at
/// least [kShiftMinimumRise]; otherwise a fourth measurement merely above the
/// coverline confirms it instead.
TemperatureShift? detectTemperatureShift(List<double?> temperatures) {
  for (var i = 6; i + 2 < temperatures.length; i++) {
    final lows = temperatures.sublist(i - 6, i);
    final first = temperatures[i];
    final second = temperatures[i + 1];
    final third = temperatures[i + 2];
    if (lows.contains(null) ||
        first == null ||
        second == null ||
        third == null) {
      continue;
    }

    final coverline = lows.cast<double>().reduce(max);
    if (!(first > coverline && second > coverline && third > coverline)) {
      continue;
    }

    final lowestHigher = min(first, min(second, third));
    if (third >= coverline + kShiftMinimumRise) {
      return TemperatureShift(
        ovulationDay: i,
        confirmationDay: i + 3,
        coverline: coverline,
        lowestHigherTemperature: lowestHigher,
      );
    }

    final fourth = i + 3 < temperatures.length ? temperatures[i + 3] : null;
    if (fourth != null && fourth > coverline) {
      return TemperatureShift(
        ovulationDay: i,
        confirmationDay: i + 4,
        coverline: coverline,
        lowestHigherTemperature: lowestHigher,
      );
    }
  }
  return null;
}
