import '../models/cycle.dart';
import '../models/day_entry.dart';
import '../models/signs.dart';
import 'fertility_window.dart';
import 'temperature_shift.dart';

/// How far the temperature rule got in a cycle, and why it stopped there.
enum TemperatureOutcome {
  /// Not a single usable measurement in the cycle.
  noMeasurements,

  /// Measurements exist, but never six before a rise, so the coverline could
  /// never be drawn.
  tooFewMeasurements,

  /// Enough measurements, but no run of higher ones held above the coverline.
  noSustainedRise,

  /// The third higher measurement reached the minimum rise and closed it.
  confirmedOnThird,

  /// The third fell short of the minimum rise and a fourth confirmed instead.
  confirmedOnFourth,

  /// A measurement fell back to the coverline, was disregarded, and a further
  /// one confirmed.
  confirmedAfterDisregarded,
}

/// A rise the record shows but the rule cannot use, because fewer than the six
/// low measurements it rests on precede it.
class UnevaluableRise {
  /// 1-based cycle day the rise appears on.
  final int day;

  /// Measurements recorded before it in this cycle.
  final int measurementsBefore;

  const UnevaluableRise({required this.day, required this.measurementsBefore});
}

/// What the rules made of one cycle, as facts rather than prose: which rule
/// opened the window, how far the temperature evaluation got, what was logged,
/// and where the record fell short of what the rules need.
///
/// Kept apart from the analyzer so the explanation can be assembled and tested
/// without re-running the engine, and worded by the UI rather than here.
class CycleEvaluation {
  final Cycle cycle;
  final FertilityWindow window;
  final TemperatureOutcome outcome;

  /// Usable measurements in the cycle - excluded ones do not count.
  final int measurements;

  /// Measurements the user marked as disturbed.
  final int excludedMeasurements;

  /// Days inside the cycle with no entry at all.
  final int daysWithoutEntry;

  /// Earliest and latest time of day a temperature was taken, when at least two
  /// carry a time. A wide spread is worth pointing out: the reading drifts with
  /// the hour it was taken at.
  final Duration? earliestMeasurementTime;
  final Duration? latestMeasurementTime;

  /// 1-based cycle day of the measurement that was disregarded under the second
  /// exception, when one was.
  final int? disregardedDay;

  /// A rise the six-low requirement could not be applied to, when the cycle
  /// holds one.
  final UnevaluableRise? unevaluableRise;

  /// First day fertile-type mucus was logged, and the last peak-quality day.
  final int? mucusOnsetDay;
  final int? mucusPeakDay;

  /// Days carrying any mucus observation, including dry and none-of-note ones.
  final int mucusDaysLogged;

  const CycleEvaluation({
    required this.cycle,
    required this.window,
    required this.outcome,
    required this.measurements,
    required this.excludedMeasurements,
    required this.daysWithoutEntry,
    required this.mucusDaysLogged,
    this.earliestMeasurementTime,
    this.latestMeasurementTime,
    this.disregardedDay,
    this.unevaluableRise,
    this.mucusOnsetDay,
    this.mucusPeakDay,
  });

  /// Whether the temperature evaluation completed.
  bool get isEvaluated =>
      outcome == TemperatureOutcome.confirmedOnThird ||
      outcome == TemperatureOutcome.confirmedOnFourth ||
      outcome == TemperatureOutcome.confirmedAfterDisregarded;

  /// How far the confirming measurement cleared the coverline, in hundredths of
  /// a degree, or null when nothing confirmed.
  int? get confirmingRiseHundredths {
    final coverline = window.coverline;
    final confirming = window.confirmingTemperature;
    if (coverline == null || confirming == null) {
      return null;
    }
    return ((confirming - coverline) * 100).round();
  }

  /// Whether the rise reached the mark the rule asks of the third measurement.
  bool get reachedMinimumRise {
    final rise = confirmingRiseHundredths;
    return rise != null && rise >= (kShiftMinimumRise * 100).round();
  }

  /// The measurement time spread, when both ends are known.
  Duration? get measurementTimeSpread {
    final earliest = earliestMeasurementTime;
    final latest = latestMeasurementTime;
    if (earliest == null || latest == null) {
      return null;
    }
    return latest - earliest;
  }
}

/// Read off what the rules did with [cycle] and its [window].
CycleEvaluation evaluateCycle(Cycle cycle, FertilityWindow window) {
  final days = cycle.days;
  final measurements = <int>[]; // 1-based cycle days carrying a usable value
  var excluded = 0;
  var withoutEntry = 0;
  var mucusDays = 0;
  int? mucusOnset;
  int? mucusPeak;
  Duration? earliest;
  Duration? latest;

  for (var i = 0; i < days.length; i++) {
    final day = days[i];
    final cycleDay = i + 1;
    if (day.temperatureExcluded) {
      excluded++;
    }
    if (day.temperatureForAnalysis != null) {
      measurements.add(cycleDay);
      final at = day.temperatureAt;
      if (at != null) {
        final time = Duration(hours: at.hour, minutes: at.minute);
        earliest = earliest == null || time < earliest ? time : earliest;
        latest = latest == null || time > latest ? time : latest;
      }
    }
    if (day.mucus != CervicalMucus.none) {
      mucusDays++;
      if (mucusOnset == null && day.mucus.isPresent) {
        mucusOnset = cycleDay;
      }
      if (day.mucus.isPeak) {
        mucusPeak = cycleDay;
      }
    }
    if (!_hasAnything(day)) {
      withoutEntry++;
    }
  }

  final disregardedDay = window.confirmed
      ? _disregardedDay(cycle, window)
      : null;

  return CycleEvaluation(
    cycle: cycle,
    window: window,
    outcome: _outcome(cycle, window, measurements.length, disregardedDay),
    measurements: measurements.length,
    excludedMeasurements: excluded,
    daysWithoutEntry: withoutEntry,
    earliestMeasurementTime: earliest,
    latestMeasurementTime: latest,
    disregardedDay: disregardedDay,
    unevaluableRise: window.confirmed ? null : _unevaluableRise(cycle),
    mucusOnsetDay: mucusOnset,
    mucusPeakDay: mucusPeak,
    mucusDaysLogged: mucusDays,
  );
}

TemperatureOutcome _outcome(
  Cycle cycle,
  FertilityWindow window,
  int measurements,
  int? disregardedDay,
) {
  if (!window.confirmed) {
    if (measurements == 0) {
      return TemperatureOutcome.noMeasurements;
    }
    // Six lows and three higher measurements are the least the rule can work
    // with; below that the cycle was never in reach of an evaluation.
    return measurements < 9
        ? TemperatureOutcome.tooFewMeasurements
        : TemperatureOutcome.noSustainedRise;
  }
  if (disregardedDay != null) {
    return TemperatureOutcome.confirmedAfterDisregarded;
  }
  final counted = _higherMeasurementCount(cycle, window);
  return counted > 3
      ? TemperatureOutcome.confirmedOnFourth
      : TemperatureOutcome.confirmedOnThird;
}

/// Measurements above the coverline from the first higher one to the day the
/// evaluation closed.
int _higherMeasurementCount(Cycle cycle, FertilityWindow window) {
  final coverline = window.coverline!;
  var count = 0;
  for (var day = window.ovulationDay + 1; day <= window.lastFertileDay; day++) {
    if (day > cycle.length) {
      break;
    }
    final value = cycle.dayOfCycle(day).temperatureForAnalysis;
    if (value != null && value > coverline) {
      count++;
    }
  }
  return count;
}

/// The day a measurement fell back onto or below the coverline inside a
/// confirmed rise - the one the second exception disregards.
int? _disregardedDay(Cycle cycle, FertilityWindow window) {
  final coverline = window.coverline!;
  for (var day = window.ovulationDay + 1; day <= window.lastFertileDay; day++) {
    if (day > cycle.length) {
      break;
    }
    final value = cycle.dayOfCycle(day).temperatureForAnalysis;
    if (value != null && value <= coverline) {
      return day;
    }
  }
  return null;
}

/// The first measurement that rises clearly above everything measured before it
/// in the cycle while fewer than six measurements precede it.
///
/// This is the shape of a cycle whose curve shows an obvious rise the rule still
/// cannot use, and naming the day makes the gap actionable: the days before it
/// were the ones that needed measuring.
UnevaluableRise? _unevaluableRise(Cycle cycle) {
  double? highestSoFar;
  var before = 0;
  for (var i = 0; i < cycle.days.length; i++) {
    final value = cycle.days[i].temperatureForAnalysis;
    if (value == null) {
      continue;
    }
    final previousHigh = highestSoFar;
    if (previousHigh != null &&
        before < 6 &&
        value >= previousHigh + kFirstHigherMinimumMargin) {
      return UnevaluableRise(day: i + 1, measurementsBefore: before);
    }
    highestSoFar = previousHigh == null || value > previousHigh
        ? value
        : previousHigh;
    before++;
  }
  return null;
}

/// Whether anything at all was logged for the day, temperature included.
bool _hasAnything(DayEntry day) => day.temperature != null || day.hasUserEntry;
