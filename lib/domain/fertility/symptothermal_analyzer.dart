import 'dart:math';

import '../models/cycle.dart';
import '../models/signs.dart';
import 'fertility_window.dart';
import 'temperature_shift.dart';

/// Length of the luteal phase, used to predict ovulation before it is confirmed.
const int _lutealLength = 14;

/// The symptothermal "minus 8" calendar-rule offset.
const int _minus8Offset = 8;

/// Documented cycles required before the "minus 8" rule is trusted; until then
/// the conservative five-day rule applies.
const int _documentedCyclesForMinus8 = 12;

/// Five-day rule: fertility is assumed from this cycle day while still learning.
const int _fiveDayRuleFirstFertile = 6;

/// Fallback cycle length when there is no history to average.
const int _defaultCycleLength = 28;

/// Computes fertile windows from cycle history using the symptothermal method.
abstract interface class FertilityAnalyzer {
  /// Analyze [cycles] (ordered oldest-first) and return one window per cycle in
  /// the same order.
  List<FertilityWindow> analyze(List<Cycle> cycles);
}

/// Per-cycle facts extracted once, before the cross-cycle rules run.
class _CycleFacts {
  final Cycle cycle;
  final TemperatureShift? shift;
  final int? mucusOnset;
  final int? mucusPeak;

  const _CycleFacts({
    required this.cycle,
    required this.shift,
    required this.mucusOnset,
    required this.mucusPeak,
  });

  bool get isOvulatory => shift != null;

  /// First higher measurement day (the day after ovulation), used by the
  /// "minus 8" calendar rule.
  int? get firstHigherMeasurementDay =>
      shift == null ? null : shift!.ovulationDay + 1;
}

/// Sensiplan implementation of the symptothermal method.
///
/// Start of fertility is the earlier of two signals: mucus onset, or the
/// calendar bound (the five-day rule while fewer than twelve cycles are
/// documented, then the "minus 8" rule computed from the earliest first higher
/// measurement of the most recent twelve completed cycles). End of fertility is
/// the later of the temperature confirmation and the mucus peak plus three days.
class SensiplanAnalyzer implements FertilityAnalyzer {
  const SensiplanAnalyzer();

  @override
  List<FertilityWindow> analyze(List<Cycle> cycles) {
    final facts = cycles.map(_extractFacts).toList();
    // Only cycles with a known start have a valid length and cycle-day numbering,
    // so the calendar and prediction rules draw on those alone.
    final completed = facts
        .where((f) => !f.cycle.isCurrent && f.cycle.hasKnownStart)
        .toList();
    final earliestFhm = _minus8EarliestFirstHigherMeasurement(completed);
    final predictedOvulation = _predictedOvulationDay(completed);

    final windows = <FertilityWindow>[];
    _CycleFacts? previousKnown;
    for (var i = 0; i < facts.length; i++) {
      final factsForCycle = facts[i];
      if (!factsForCycle.cycle.hasKnownStart) {
        windows.add(const FertilityWindow.none());
        continue;
      }
      windows.add(
        _windowFor(
          factsForCycle,
          previousKnown,
          earliestFhm,
          predictedOvulation,
        ),
      );
      previousKnown = factsForCycle;
    }
    return windows;
  }

  _CycleFacts _extractFacts(Cycle cycle) {
    final temperatures = cycle.days.map((d) => d.temperature).toList();
    final shift = detectTemperatureShift(temperatures);

    int? onset;
    int? peak;
    for (var i = 0; i < cycle.days.length; i++) {
      final mucus = cycle.days[i].mucus;
      final cycleDay = i + 1;
      if (onset == null && mucus.isPresent) {
        onset = cycleDay;
      }
      if (mucus.isPeak) {
        peak = cycleDay;
      }
    }
    return _CycleFacts(
      cycle: cycle,
      shift: shift,
      mucusOnset: onset,
      mucusPeak: peak,
    );
  }

  /// Earliest first higher measurement across the most recent twelve completed
  /// cycles, or null while the "minus 8" rule is not yet trusted.
  int? _minus8EarliestFirstHigherMeasurement(List<_CycleFacts> completed) {
    if (completed.length < _documentedCyclesForMinus8) {
      return null;
    }
    final recent = completed.sublist(
      completed.length - _documentedCyclesForMinus8,
    );
    int? earliest;
    for (final facts in recent) {
      final fhm = facts.firstHigherMeasurementDay;
      if (fhm == null) {
        continue;
      }
      earliest = earliest == null ? fhm : min(earliest, fhm);
    }
    return earliest;
  }

  int _predictedOvulationDay(List<_CycleFacts> completed) {
    if (completed.isEmpty) {
      return _defaultCycleLength - _lutealLength;
    }
    final total = completed.fold<int>(0, (sum, f) => sum + f.cycle.length);
    final average = (total / completed.length).round();
    return average - _lutealLength;
  }

  FertilityWindow _windowFor(
    _CycleFacts facts,
    _CycleFacts? previous,
    int? earliestFhm,
    int predictedOvulation,
  ) {
    final calendarStart = _calendarStart(previous, earliestFhm);
    final start = facts.mucusOnset == null
        ? calendarStart
        : min(calendarStart, facts.mucusOnset!);

    final shift = facts.shift;
    if (shift == null) {
      final ovulation = max(1, predictedOvulation);
      return FertilityWindow(
        firstFertileDay: start,
        lastFertileDay: ovulation + 1,
        ovulationDay: ovulation,
        confirmed: false,
      );
    }

    final mucusEnd = facts.mucusPeak == null
        ? shift.confirmationDay
        : facts.mucusPeak! + 3;
    final end = max(shift.confirmationDay, mucusEnd);
    return FertilityWindow(
      firstFertileDay: start,
      lastFertileDay: end,
      ovulationDay: shift.ovulationDay,
      confirmed: true,
      coverline: shift.coverline,
      lowestHigherTemperature: shift.lowestHigherTemperature,
    );
  }

  int _calendarStart(_CycleFacts? previous, int? earliestFhm) {
    if (earliestFhm != null) {
      return earliestFhm - _minus8Offset + 1;
    }
    // Five-day rule while learning: trust day six only after an ovulatory cycle,
    // otherwise treat the whole cycle as potentially fertile.
    final previousOvulatory = previous == null || previous.isOvulatory;
    return previousOvulatory ? _fiveDayRuleFirstFertile : 1;
  }
}
