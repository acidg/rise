import 'dart:math';

/// The third higher measurement must exceed the coverline by at least this many
/// degrees Celsius for a same-day confirmation.
const double kShiftMinimumRise = 0.2;

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

  /// Lowest of the higher measurements that confirm the shift - the three (or
  /// four, under the exception) measurements above the coverline that close the
  /// fertile window. The upper reference line rests on this point.
  final double lowestHigherTemperature;

  const TemperatureShift({
    required this.ovulationDay,
    required this.confirmationDay,
    required this.firstLowDay,
    required this.coverline,
    required this.lowestHigherTemperature,
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
/// rise. The shift confirms on the third higher measurement when it clears the
/// coverline by at least [kShiftMinimumRise]; otherwise a fourth measurement
/// merely above the coverline confirms it instead.
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
    if (!(firstHigher > coverline)) {
      continue;
    }
    final shift = _confirmShift(temperatures, first, coverline, lows.firstDay);
    if (shift != null) {
      return shift;
    }
  }
  return null;
}

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
/// values, all of which must stay above [coverline], and apply the three- and
/// four-over-six confirmation rules. Returns null when a measured value falls
/// back to the coverline or the higher measurements run out before confirming.
TemperatureShift? _confirmShift(
  List<double?> temperatures,
  int first,
  double coverline,
  int firstLowDay,
) {
  final higherValues = <double>[temperatures[first]!];
  var lastIndex = first;
  for (var i = first + 1; i < temperatures.length; i++) {
    final value = temperatures[i];
    if (value == null) {
      continue;
    }
    if (!(value > coverline)) {
      return null;
    }
    higherValues.add(value);
    lastIndex = i;

    if (higherValues.length == _higherMeasurementCount) {
      if (value >= coverline + kShiftMinimumRise) {
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
    lowestHigherTemperature: higherValues.reduce(min),
  );
}
