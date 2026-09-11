import 'package:flutter_test/flutter_test.dart';
import 'package:rise/domain/fertility/symptothermal_analyzer.dart';
import 'package:rise/domain/models/cycle.dart';
import 'package:rise/domain/models/signs.dart';

import '../support/cycle_builder.dart';

void main() {
  const analyzer = SensiplanAnalyzer();

  group('start of the fertile window', () {
    test('mucus onset opens it earlier than the calendar rule', () {
      final cycle = buildCycle(
        temperatures: biphasic(lowDays: 12),
        mucus: {
          4: CervicalMucus.sticky,
        }, // onset on day 4, before calendar day 6
        isCurrent: true,
      );

      final window = analyzer.analyze([cycle]).single;

      expect(window.firstFertileDay, 4);
    });

    test('the five-day rule opens it on day six after an ovulatory cycle', () {
      final cycle = buildCycle(
        temperatures: biphasic(lowDays: 12),
        isCurrent: true,
      );

      final window = analyzer.analyze([cycle]).single;

      expect(window.firstFertileDay, 6);
    });

    test(
      'the calendar stays conservative (day one) after an anovulatory cycle',
      () {
        final cycles = [
          buildCycle(
            temperatures: List<double?>.filled(20, 36.45),
          ), // anovulatory
          buildCycle(temperatures: biphasic(lowDays: 12), isCurrent: true),
        ];

        final windows = analyzer.analyze(cycles);

        expect(windows[1].firstFertileDay, 1);
      },
    );

    test('the minus-8 rule uses only the most recent twelve completed cycles', () {
      // Oldest completed cycle has a very early rise (first higher measurement on
      // day 11). It sits outside the most recent twelve, so it must be ignored:
      // the earliest first higher measurement among the last twelve is day 14.
      final cycles = <Cycle>[
        buildCycle(temperatures: biphasic(lowDays: 10)), // FHM day 11 - ignored
        for (var i = 0; i < 11; i++)
          buildCycle(temperatures: biphasic(lowDays: 15)),
        buildCycle(
          temperatures: biphasic(lowDays: 13),
        ), // FHM day 14 - earliest kept
        buildCycle(temperatures: biphasic(lowDays: 15), isCurrent: true),
      ];

      final windows = analyzer.analyze(cycles);

      // minus-8: earliest FHM (14) - 8 + 1 = day 7. Had the day-11 cycle counted,
      // it would have been day 4.
      expect(windows.last.firstFertileDay, 7);
    });
  });

  group('end of the fertile window', () {
    test('closes on the mucus peak plus three days when that is later than the '
        'temperature confirmation', () {
      final cycle = buildCycle(
        temperatures: biphasic(
          lowDays: 12,
        ), // ovulation day 12, confirmed day 15
        mucus: {
          13: CervicalMucus.eggWhite,
        }, // peak day 13 -> plus three = day 16
      );

      final window = analyzer.analyze([cycle]).single;

      expect(window.ovulationDay, 12);
      expect(window.lastFertileDay, 16);
    });

    test('closes on the temperature confirmation when that is later than the '
        'mucus peak plus three days', () {
      final cycle = buildCycle(
        temperatures: biphasic(lowDays: 12), // confirmed day 15
        mucus: {
          10: CervicalMucus.eggWhite,
        }, // peak day 10 -> plus three = day 13
      );

      final window = analyzer.analyze([cycle]).single;

      expect(window.lastFertileDay, 15);
    });
  });

  group('signals available', () {
    test(
      'temperature alone confirms ovulation and closes three days later',
      () {
        final cycle = buildCycle(temperatures: biphasic(lowDays: 12));

        final window = analyzer.analyze([cycle]).single;

        expect(window.confirmed, isTrue);
        expect(window.ovulationDay, 12);
        expect(
          window.firstFertileDay,
          6,
        ); // calendar only, no mucus to open earlier
        expect(
          window.lastFertileDay,
          15,
        ); // ovulation + 3, no mucus peak to extend
        expect(window.coverline, 36.40);
      },
    );

    test(
      'an anovulatory cycle stays unconfirmed with an open predicted window',
      () {
        final cycle = buildCycle(
          temperatures: List<double?>.filled(20, 36.45),
          isCurrent: true,
        );

        final window = analyzer.analyze([cycle]).single;

        expect(window.confirmed, isFalse);
        expect(window.coverline, isNull);
        expect(window.lastFertileDay, window.ovulationDay + 1);
      },
    );
  });

  test(
    'an excluded measurement counts as a gap, not as a higher measurement',
    () {
      final temperatures = biphasic(lowDays: 6, highDays: 4);

      final undisturbed = analyzer.analyze([
        buildCycle(temperatures: temperatures, isCurrent: true),
      ]).single;
      final disturbed = analyzer.analyze([
        buildCycle(
          temperatures: temperatures,
          excludedTemperatureDays: {7}, // the first higher measurement
          isCurrent: true,
        ),
      ]).single;

      expect(undisturbed.ovulationDay, 6);
      expect(undisturbed.lastFertileDay, 9);
      // Without day 7 the rise starts a day later and confirms a day later.
      expect(disturbed.ovulationDay, 7);
      expect(disturbed.lastFertileDay, 10);
    },
  );

  group('a window with nothing to evaluate', () {
    test('is marked unevaluated when the previous cycle carried no rise', () {
      // Neither rule applies: too few documented cycles for "minus 8", and a
      // previous cycle without a temperature shift for the five-day rule.
      final previous = buildCycle(temperatures: List.filled(26, null));
      final current = buildCycle(
        temperatures: List.filled(10, null),
        isCurrent: true,
      );

      final windows = analyzer.analyze([previous, current]);

      expect(windows.last.unevaluated, isTrue);
      expect(windows.last.firstFertileDay, 1);
    });

    test('is not marked once the previous cycle is ovulatory', () {
      final previous = buildCycle(temperatures: biphasic(lowDays: 12));
      final current = buildCycle(
        temperatures: List.filled(10, null),
        isCurrent: true,
      );

      final windows = analyzer.analyze([previous, current]);

      expect(windows.last.unevaluated, isFalse);
      expect(windows.last.firstFertileDay, 6);
    });

    test('is not marked once this cycle confirms its own shift', () {
      final previous = buildCycle(temperatures: List.filled(26, null));
      final current = buildCycle(
        temperatures: biphasic(lowDays: 12),
        isCurrent: true,
      );

      final windows = analyzer.analyze([previous, current]);

      expect(windows.last.unevaluated, isFalse);
      expect(windows.last.confirmed, isTrue);
    });
  });

  group('predicted ovulation', () {
    test('averages the cycle lengths', () {
      final cycles = [
        for (var i = 0; i < 3; i++)
          buildCycle(temperatures: List.filled(26, null)),
        buildCycle(temperatures: List.filled(10, null), isCurrent: true),
      ];

      final window = analyzer.analyze(cycles).last;

      expect(window.ovulationDay, 26 - 14);
    });

    test('leaves an implausibly long run out of the average', () {
      // A stretch where bleeding went unlogged is one long run, not a cycle;
      // averaging it in would push the prediction days late.
      final cycles = [
        for (var i = 0; i < 3; i++)
          buildCycle(temperatures: List.filled(26, null)),
        buildCycle(temperatures: List.filled(200, null)),
        buildCycle(temperatures: List.filled(10, null), isCurrent: true),
      ];

      final window = analyzer.analyze(cycles).last;

      expect(window.ovulationDay, 26 - 14);
    });
  });

  test('an unconfirmed window still honours the mucus peak', () {
    // No temperature evaluation is possible (five measurements before the rise,
    // one short of the six the rule needs), but egg-white mucus was logged on
    // day 13, so the window cannot close before day 16 - least of all on the
    // calendar guess, which lands earlier.
    final cycle = buildCycle(
      temperatures: [
        null, null, null, null, null, null, null, null, null, //
        36.69, 36.53, 36.63, 36.50, 36.62, 37.04, 37.11, 36.86, 37.09,
      ],
      mucus: {
        11: CervicalMucus.sticky,
        12: CervicalMucus.creamy,
        13: CervicalMucus.eggWhite,
      },
    );

    final window = analyzer.analyze([cycle]).single;

    expect(window.confirmed, isFalse);
    expect(window.lastFertileDay, 16);
  });
}
