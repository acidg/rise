import 'package:flutter_test/flutter_test.dart';
import 'package:rise/domain/fertility/cycle_evaluation.dart';
import 'package:rise/domain/fertility/symptothermal_analyzer.dart';
import 'package:rise/domain/models/cycle.dart';
import 'package:rise/domain/models/day_entry.dart';
import 'package:rise/domain/models/signs.dart';

import '../support/cycle_builder.dart';

void main() {
  const analyzer = SensiplanAnalyzer();

  CycleEvaluation evaluate(Cycle cycle) =>
      evaluateCycle(cycle, analyzer.analyze([cycle]).single);

  test('a textbook rise is reported as confirmed on the third measurement', () {
    final evaluation = evaluate(buildCycle(temperatures: biphasic(lowDays: 8)));

    expect(evaluation.outcome, TemperatureOutcome.confirmedOnThird);
    expect(evaluation.isEvaluated, isTrue);
    expect(evaluation.reachedMinimumRise, isTrue);
    expect(evaluation.confirmingRiseHundredths, 35);
  });

  test('a rise confirmed by the fourth measurement is reported as such', () {
    final evaluation = evaluate(
      buildCycle(
        temperatures: [
          36.40, 36.40, 36.40, 36.40, 36.40, 36.40, //
          36.50, 36.55, 36.52, 36.48,
        ],
      ),
    );

    expect(evaluation.outcome, TemperatureOutcome.confirmedOnFourth);
    expect(evaluation.reachedMinimumRise, isFalse);
  });

  test('a disregarded measurement is reported with its day', () {
    final evaluation = evaluate(
      buildCycle(
        temperatures: [
          36.40, 36.40, 36.40, 36.40, 36.40, 36.40, //
          36.50, 36.38, 36.55, 36.62,
        ],
      ),
    );

    expect(evaluation.outcome, TemperatureOutcome.confirmedAfterDisregarded);
    expect(evaluation.disregardedDay, 8);
  });

  test('a cycle without measurements says so', () {
    final evaluation = evaluate(
      buildCycle(temperatures: List.filled(26, null)),
    );

    expect(evaluation.outcome, TemperatureOutcome.noMeasurements);
    expect(evaluation.measurements, 0);
    expect(evaluation.isEvaluated, isFalse);
  });

  test('a rise with too few measurements before it is named with its day', () {
    // Measuring only started on day 10: five readings precede the rise on day
    // 15, one short of the six the coverline rests on.
    final evaluation = evaluate(
      buildCycle(
        temperatures: [
          null, null, null, null, null, null, null, null, null, //
          36.69, 36.53, 36.63, 36.50, 36.62, 37.04, 37.11, 36.86, 37.09,
        ],
      ),
    );

    expect(evaluation.isEvaluated, isFalse);
    expect(evaluation.unevaluableRise, isNotNull);
    expect(evaluation.unevaluableRise!.day, 15);
    expect(evaluation.unevaluableRise!.measurementsBefore, 5);
  });

  test('mucus observations are summarised', () {
    final evaluation = evaluate(
      buildCycle(
        temperatures: biphasic(lowDays: 8),
        mucus: {
          3: CervicalMucus.dry,
          5: CervicalMucus.sticky,
          6: CervicalMucus.eggWhite,
        },
      ),
    );

    expect(evaluation.mucusDaysLogged, 3);
    expect(evaluation.mucusOnsetDay, 5);
    expect(evaluation.mucusPeakDay, 6);
  });

  test('the spread of measurement times is reported', () {
    final base = DateTime(2026, 1, 1);
    final cycle = Cycle(
      days: [
        for (var i = 0; i < 3; i++)
          DayEntry(
            date: base.add(Duration(days: i)),
            temperature: 36.40,
            temperatureAt: base.add(Duration(days: i, hours: 6 + i * 2)),
            menstruation: i == 0 ? Menstruation.medium : Menstruation.none,
          ),
      ],
    );

    final evaluation = evaluate(cycle);

    expect(evaluation.earliestMeasurementTime, const Duration(hours: 6));
    expect(evaluation.latestMeasurementTime, const Duration(hours: 10));
    expect(evaluation.measurementTimeSpread, const Duration(hours: 4));
  });

  test('excluded measurements are counted and left out of the evaluation', () {
    final evaluation = evaluate(
      buildCycle(
        temperatures: biphasic(lowDays: 8),
        excludedTemperatureDays: {3},
      ),
    );

    expect(evaluation.excludedMeasurements, 1);
    expect(evaluation.measurements, 11);
  });
}
