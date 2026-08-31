import 'package:flutter_test/flutter_test.dart';
import 'package:rise/domain/fertility/temperature_shift.dart';

void main() {
  group('detectTemperatureShift', () {
    test(
      'confirms on the third higher measurement when it clears the coverline '
      'by 0.2 C',
      () {
        final temps = <double?>[
          36.40,
          36.40,
          36.40,
          36.40,
          36.40,
          36.40, // six lows (coverline 36.40)
          36.70, 36.80, 36.75, // three higher measurements
        ];

        final shift = detectTemperatureShift(temps);

        expect(shift, isNotNull);
        expect(shift!.ovulationDay, 6);
        expect(shift.confirmationDay, 9); // third higher measurement
        expect(shift.firstLowDay, 1); // six unbroken lows begin on day one
        expect(shift.coverline, 36.40);
        expect(shift.lowestHigherTemperature, 36.70);
      },
    );

    test(
      'applies the fourth-day exception when the third higher measurement is '
      'above the coverline but not 0.2 C above it',
      () {
        final temps = <double?>[
          36.40, 36.40, 36.40, 36.40, 36.40, 36.40,
          36.50, 36.55, 36.52, // above coverline, but third is only +0.12
          36.48, // fourth measurement above the coverline closes it
        ];

        final shift = detectTemperatureShift(temps);

        expect(shift, isNotNull);
        expect(shift!.ovulationDay, 6);
        expect(shift.confirmationDay, 10); // fourth measurement
        // The fourth measurement confirms the shift, so it is part of the
        // higher measurements: the lowest higher point must include it.
        expect(shift.lowestHigherTemperature, 36.48);
      },
    );

    test('returns null for an anovulatory cycle with no sustained rise', () {
      final temps = List<double?>.filled(20, 36.45);

      expect(detectTemperatureShift(temps), isNull);
    });

    test('a measurement equal to the coverline does not count as higher', () {
      final temps = <double?>[
        36.40, 36.40, 36.40, 36.40, 36.40, 36.40,
        36.40, // equal to the coverline, so not a higher measurement
        36.70, 36.70, 36.70,
      ];

      final shift = detectTemperatureShift(temps);

      // The rise is only recognised from the next day, one cycle day later.
      expect(shift, isNotNull);
      expect(shift!.ovulationDay, 7);
    });

    test('a missing measurement in the low phase is bridged by reaching further '
        'back for a sixth low', () {
      final temps = <double?>[
        36.40, 36.40, 36.40,
        null, // no measurement during bleeding
        36.40, 36.40, 36.40, // six measured lows span the gap (days 1-3, 5-7)
        36.70, 36.80, 36.75, // three higher measurements
      ];

      final shift = detectTemperatureShift(temps);

      expect(shift, isNotNull);
      expect(shift!.ovulationDay, 7);
      expect(shift.confirmationDay, 10);
      // The coverline rests on six measured lows reached back over the gap, so
      // the reference band opens on cycle day one, not ovulation day minus five.
      expect(shift.firstLowDay, 1);
      expect(shift.coverline, 36.40);
    });

    test(
      'a missing measurement between higher measurements is stepped over',
      () {
        final temps = <double?>[
          36.40, 36.40, 36.40, 36.40, 36.40, 36.40,
          36.70,
          null, // a skipped day between higher measurements
          36.70, 36.70, // still three measured highers above the coverline
        ];

        final shift = detectTemperatureShift(temps);

        expect(shift, isNotNull);
        expect(shift!.ovulationDay, 6);
        // The third measured higher lands on cycle day ten, closing the window.
        expect(shift.confirmationDay, 10);
        expect(shift.coverline, 36.40);
        expect(shift.lowestHigherTemperature, 36.70);
      },
    );

    test(
      'a measured value that falls back to the coverline breaks the rise',
      () {
        final temps = <double?>[
          36.40, 36.40, 36.40, 36.40, 36.40, 36.40,
          36.70,
          36.40, // falls back to the coverline: not a sustained shift
          36.70, 36.70,
        ];

        expect(detectTemperatureShift(temps), isNull);
      },
    );
  });
}
