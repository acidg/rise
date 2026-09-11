import 'dart:math';

/// The third higher measurement must exceed the coverline by at least this many
/// degrees Celsius for a same-day confirmation.
const double kShiftMinimumRise = 0.2;

/// The first higher measurement must clear the coverline by at least this many
/// degrees Celsius (compared in hundredths, the precision temperatures are
/// recorded at).
///
/// Sensiplan asks only that it lie above the coverline, by any amount. A reading
/// two hundredths above the highest of the six lows sits inside the noise of a
/// basal measurement, and taking it as the rise dates ovulation a day early and
/// closes the fertile window two days early. Requiring a small margin is a
/// deliberate departure from the strict rule, and only ever in the cautious
/// direction: it can delay a shift or leave it unconfirmed, never the reverse.
/// The measurements that follow need only stay above the coverline, as the
/// method prescribes.
const double kFirstHigherMinimumMargin = 0.05;

/// Number of low measurements the coverline is drawn over (Sensiplan "six").
const int _lowMeasurementCount = 6;

/// Higher measurements needed to confirm the shift in the normal case.
const int _higherMeasurementCount = 3;

/// Higher measurements needed under the fourth-day exception.
const int _exceptionHigherMeasurementCount = 4;

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

  /// Cycle day of the earliest of the six low measurements the coverline rests
  /// on. With no gaps this is `ovulationDay - 5`; measurement gaps in the low
  /// phase push it earlier, because the six are counted over measured days.
  final int firstLowDay;

  /// Highest of the six low measurements before the rise (the coverline).
  final double coverline;

  /// The measurement that completed the evaluation: the third higher one when it
  /// reached [kShiftMinimumRise] above the coverline, otherwise the fourth that
  /// confirmed it instead, or the further one awaited after a measurement was
  /// disregarded. The upper reference line rests on it, so the line marks the
  /// day the temperature closed the fertile window and the gap drawn is that
  /// day's distance from the coverline.
  final double confirmingTemperature;

  const TemperatureShift({
    required this.ovulationDay,
    required this.confirmationDay,
    required this.firstLowDay,
    required this.coverline,
    required this.confirmingTemperature,
  });
}

/// Detect the temperature shift in a cycle's ordered daily temperatures.
///
/// [temperatures] is indexed by cycle day minus one (`temperatures[0]` is cycle
/// day 1). Missing measurements are null. Returns null when no valid shift is
/// present (an anovulatory cycle, or too little data).
///
/// Rule (Sensiplan "three over six"): find three consecutive higher measurements
/// above the coverline - the highest of the six low measurements before the
/// rise. The first of them must clear the coverline by
/// [kFirstHigherMinimumMargin], so a reading inside measurement noise does not
/// open the rise. The shift confirms on the third higher measurement when it
/// clears the coverline by at least [kShiftMinimumRise]; otherwise a fourth
/// measurement merely above the coverline confirms it instead.
///
/// Measurement gaps are bridged the way Sensiplan prescribes: the "six" lows and
/// the "three" (or four) highers are counted over measured days, skipping empty
/// days rather than resetting on them. A missing day in the low phase reaches
/// further back for a sixth low; a missing day between higher measurements is
/// stepped over. Only a measured value that falls back to the coverline breaks
/// the rise.
TemperatureShift? detectTemperatureShift(List<double?> temperatures) {
  for (var first = 0; first < temperatures.length; first++) {
    final firstHigher = temperatures[first];
    if (firstHigher == null) {
      continue;
    }
    final lows = _sixLowsBefore(temperatures, first);
    if (lows == null) {
      continue;
    }
    final coverline = lows.values.reduce(max);
    if (!_atLeast(firstHigher, coverline + kFirstHigherMinimumMargin)) {
      continue;
    }
    final shift = _confirmShift(temperatures, first, coverline, lows.firstDay);
    if (shift != null) {
      return shift;
    }
  }
  return null;
}

/// Whether [value] reaches [threshold], compared in hundredths of a degree.
/// Temperatures are recorded to two decimals, and adding a threshold to one in
/// binary floating point overshoots it (36.42 + 0.2 is 36.620000000000005), so a
/// reading exactly on the threshold would otherwise fall short of it.
bool _atLeast(double value, double threshold) =>
    (value * 100).round() >= (threshold * 100).round();

/// The six measured low values immediately before [first], reached back over any
/// measurement gaps, together with the cycle day of the earliest one. Null when
/// fewer than six measured values precede [first].
({List<double> values, int firstDay})? _sixLowsBefore(
  List<double?> temperatures,
  int first,
) {
  final values = <double>[];
  var firstIndex = first;
  for (var i = first - 1; i >= 0 && values.length < _lowMeasurementCount; i--) {
    final value = temperatures[i];
    if (value == null) {
      continue;
    }
    values.add(value);
    firstIndex = i;
  }
  if (values.length < _lowMeasurementCount) {
    return null;
  }
  return (values: values, firstDay: firstIndex + 1);
}

/// Walk forward from the first higher measurement collecting measured higher
/// values and apply the confirmation rules. Returns null when the rise breaks or
/// the measurements run out before confirming.
///
/// Two exceptions of the method apply here. A third measurement that stays below
/// [kShiftMinimumRise] is confirmed instead by a fourth merely above the
/// coverline. And a second or third measurement that falls back onto or below
/// the coverline is disregarded rather than breaking the rise: it is not
/// counted, one further measurement is awaited, and that one must reach the
/// minimum rise - the fourth-day exception does not apply once a measurement has
/// been disregarded. Only one may be disregarded, and only from the second or
/// third position; a later fall back ends the rise.
TemperatureShift? _confirmShift(
  List<double?> temperatures,
  int first,
  double coverline,
  int firstLowDay,
) {
  final higherValues = <double>[temperatures[first]!];
  var lastIndex = first;
  var disregarded = false;
  for (var i = first + 1; i < temperatures.length; i++) {
    final value = temperatures[i];
    if (value == null) {
      continue;
    }
    if (!(value > coverline)) {
      if (disregarded || higherValues.length > 2) {
        return null;
      }
      disregarded = true;
      continue;
    }
    higherValues.add(value);
    lastIndex = i;

    if (disregarded) {
      if (higherValues.length >= _higherMeasurementCount &&
          _atLeast(value, coverline + kShiftMinimumRise)) {
        return _confirmed(
          first,
          lastIndex,
          firstLowDay,
          coverline,
          higherValues,
        );
      }
      continue;
    }
    if (higherValues.length == _higherMeasurementCount) {
      if (_atLeast(value, coverline + kShiftMinimumRise)) {
        return _confirmed(
          first,
          lastIndex,
          firstLowDay,
          coverline,
          higherValues,
        );
      }
      // The third measurement did not clear the coverline by the minimum rise;
      // keep going for the fourth-day exception.
      continue;
    }
    if (higherValues.length == _exceptionHigherMeasurementCount) {
      return _confirmed(first, lastIndex, firstLowDay, coverline, higherValues);
    }
  }
  return null;
}

TemperatureShift _confirmed(
  int first,
  int lastIndex,
  int firstLowDay,
  double coverline,
  List<double> higherValues,
) {
  return TemperatureShift(
    ovulationDay: first,
    confirmationDay: lastIndex + 1,
    firstLowDay: firstLowDay,
    coverline: coverline,
    confirmingTemperature: higherValues.last,
  );
}
