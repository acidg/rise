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
          36.51, // fourth measurement above the coverline closes it
        ];

        final shift = detectTemperatureShift(temps);

        expect(shift, isNotNull);
        expect(shift!.ovulationDay, 6);
        expect(shift.confirmationDay, 10); // fourth measurement
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

    test(
      'a missing measurement inside the window blocks a false confirmation',
      () {
        final temps = <double?>[
          36.40,
          36.40,
          36.40,
          36.40,
          36.40,
          36.40,
          36.70,
          null,
          36.70,
          36.70,
        ];

        expect(detectTemperatureShift(temps), isNull);
      },
    );
  });
}
