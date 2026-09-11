import '../../domain/fertility/cycle_evaluation.dart';
import '../../domain/fertility/fertility_window.dart';
import '../date_format.dart';

/// What a note is there to say, which decides how the list draws it.
enum NoteTone {
  /// The evaluation reached a result.
  result,

  /// A step of the reasoning: which rule, which day, which value.
  step,

  /// Something the record is missing that would have let the rules do more.
  advice,
}

/// One line of the explanation for a cycle.
class CycleNote {
  final NoteTone tone;
  final String text;

  const CycleNote(this.tone, this.text);
}

/// Put the evaluation of one cycle into words: what the temperature rule made of
/// it, which rule opened the window, what the mucus said, and what the record
/// would need for the rules to say more next time.
///
/// The wording lives here rather than in the domain so the rules stay free of
/// presentation, and so these sentences can be read in one place.
List<CycleNote> describeCycle(CycleEvaluation evaluation) {
  return [
    _temperatureNote(evaluation),
    ..._windowNotes(evaluation),
    ..._mucusNotes(evaluation),
    ..._advice(evaluation),
  ];
}

/// "one measurement" / "5 measurements", for sentences that count something.
String _plural(int count, String noun) =>
    count == 1 ? 'one $noun' : '$count ${noun}s';

String _date(CycleEvaluation evaluation, int cycleDay) =>
    formatDayMonth(evaluation.cycle.dayOfCycle(cycleDay).date);

String _rise(CycleEvaluation evaluation) {
  final hundredths = evaluation.confirmingRiseHundredths!;
  return '+${(hundredths / 100).toStringAsFixed(2)} C';
}

CycleNote _temperatureNote(CycleEvaluation evaluation) {
  final window = evaluation.window;
  switch (evaluation.outcome) {
    case TemperatureOutcome.noMeasurements:
      return const CycleNote(
        NoteTone.result,
        'No temperature evaluation: nothing was measured in this cycle.',
      );
    case TemperatureOutcome.tooFewMeasurements:
      return CycleNote(
        NoteTone.result,
        'No temperature evaluation: '
        '${_plural(evaluation.measurements, 'measurement')} in the cycle, and '
        'the rule needs six low ones followed by three higher.',
      );
    case TemperatureOutcome.noSustainedRise:
      return const CycleNote(
        NoteTone.result,
        'No temperature evaluation: no run of measurements stayed above the six '
        'before it.',
      );
    case TemperatureOutcome.confirmedOnThird:
      return CycleNote(
        NoteTone.result,
        'Rise confirmed on ${_date(evaluation, window.lastFertileDay)} by the '
        'third higher measurement, ${_rise(evaluation)} over the coverline.',
      );
    case TemperatureOutcome.confirmedOnFourth:
      return CycleNote(
        NoteTone.result,
        'Rise confirmed on ${_date(evaluation, window.lastFertileDay)} by a '
        'fourth measurement: the third stayed under the 0.20 C the rule asks '
        'for, so one more day was needed.',
      );
    case TemperatureOutcome.confirmedAfterDisregarded:
      return CycleNote(
        NoteTone.result,
        'Rise confirmed on ${_date(evaluation, window.lastFertileDay)}. The '
        'measurement on ${_date(evaluation, evaluation.disregardedDay!)} fell '
        'back to the coverline and was disregarded, so one further measurement '
        'was awaited.',
      );
  }
}

List<CycleNote> _windowNotes(CycleEvaluation evaluation) {
  final window = evaluation.window;
  if (!evaluation.cycle.hasKnownStart) {
    return const [
      CycleNote(
        NoteTone.result,
        'These days are not numbered: the record does not show where the cycle '
        'began, so no rule applies to them.',
      ),
    ];
  }

  final notes = <CycleNote>[
    CycleNote(NoteTone.step, _startSentence(evaluation)),
  ];
  if (window.confirmed) {
    notes.add(
      CycleNote(
        NoteTone.step,
        'Coverline at ${window.coverline!.toStringAsFixed(2)} C, first higher '
        'measurement on ${_date(evaluation, window.ovulationDay + 1)}, so '
        'ovulation is dated ${_date(evaluation, window.ovulationDay)}.',
      ),
    );
  } else {
    notes.add(
      CycleNote(
        NoteTone.step,
        'The window never closed: only a confirmed rise ends the fertile phase, '
        'so every day from ${_date(evaluation, window.firstFertileDay)} on '
        'counts as fertile.',
      ),
    );
  }
  return notes;
}

String _startSentence(CycleEvaluation evaluation) {
  final window = evaluation.window;
  final rule = switch (window.calendarRule) {
    CalendarRule.minusEight =>
      'the minus-8 rule put the earliest fertile day on day '
          '${window.calendarStartDay}',
    CalendarRule.fiveDay =>
      'the five-day rule left days 1 to 5 infertile, opening on day '
          '${window.calendarStartDay}',
    CalendarRule.none =>
      'neither calendar rule could be applied - no twelve documented cycles '
          'with a rise, and a previous cycle that could not be evaluated - so '
          'the window opens on day 1',
  };
  final onset = evaluation.mucusOnsetDay;
  if (onset != null && onset < window.calendarStartDay) {
    return 'Window opens ${_date(evaluation, window.firstFertileDay)} '
        '(day ${window.firstFertileDay}): $rule, and mucus was logged earlier, '
        'on day $onset.';
  }
  return 'Window opens ${_date(evaluation, window.firstFertileDay)} '
      '(day ${window.firstFertileDay}): $rule.';
}

List<CycleNote> _mucusNotes(CycleEvaluation evaluation) {
  if (!evaluation.cycle.hasKnownStart) {
    return const [];
  }
  final peak = evaluation.mucusPeakDay;
  if (peak == null) {
    return const [];
  }
  return [
    CycleNote(
      NoteTone.step,
      'Mucus peak on ${_date(evaluation, peak)}, which keeps the window open '
      'for three more days, to ${_date(evaluation, peak + 3)}.',
    ),
  ];
}

List<CycleNote> _advice(CycleEvaluation evaluation) {
  final notes = <CycleNote>[];
  final rise = evaluation.unevaluableRise;
  if (rise != null) {
    final before = rise.measurementsBefore == 0
        ? 'no measurements'
        : 'only ${_plural(rise.measurementsBefore, 'measurement')}';
    notes.add(
      CycleNote(
        NoteTone.advice,
        'The curve rises on ${_date(evaluation, rise.day)} with $before before '
        'it, and the coverline rests on six. Measuring from the first days of '
        'the cycle would have made this rise usable.',
      ),
    );
  } else if (evaluation.outcome == TemperatureOutcome.noMeasurements ||
      evaluation.outcome == TemperatureOutcome.tooFewMeasurements) {
    notes.add(
      const CycleNote(
        NoteTone.advice,
        'Measure on waking, every day from the start of the cycle: six low '
        'readings before the rise and three after it are what an evaluation '
        'takes.',
      ),
    );
  }

  final spread = evaluation.measurementTimeSpread;
  if (spread != null && spread.inMinutes > 90) {
    notes.add(
      CycleNote(
        NoteTone.advice,
        'Measurement times ranged from '
        '${_time(evaluation.earliestMeasurementTime!)} to '
        '${_time(evaluation.latestMeasurementTime!)}. The reading drifts with '
        'the hour it is taken at, so a steadier time sharpens the curve.',
      ),
    );
  }

  if (evaluation.mucusDaysLogged == 0) {
    notes.add(
      const CycleNote(
        NoteTone.advice,
        'No mucus logged. It is the second sign of the method: it opens the '
        'window earlier than the calendar can and holds it open for three days '
        'past its peak.',
      ),
    );
  }

  if (evaluation.excludedMeasurements > 0) {
    notes.add(
      CycleNote(
        NoteTone.step,
        '${_plural(evaluation.excludedMeasurements, 'measurement')} excluded '
        'as disturbed and left out of the evaluation.',
      ),
    );
  }
  return notes;
}

String _time(Duration time) {
  final hours = time.inHours.toString().padLeft(2, '0');
  final minutes = (time.inMinutes % 60).toString().padLeft(2, '0');
  return '$hours:$minutes';
}
