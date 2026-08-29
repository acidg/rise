import 'package:flutter_test/flutter_test.dart';
import 'package:rise/ble/ovy_protocol.dart';

void main() {
  group('parseMeasurementRecord', () {
    test('decodes the temperature and timestamp of a real record', () {
      // Worked example from the reverse-engineered protocol:
      // 06 33 0e 00 fe ea 07 02 02 06 2d 0e 06 -> 2026-02-02 06:45:14, 36.35 C.
      final record = [
        0x06, 0x33, 0x0e, 0x00, 0xfe, 0xea, 0x07, //
        0x02, 0x02, 0x06, 0x2d, 0x0e, 0x06,
      ];

      final measurement = parseMeasurementRecord(record);

      expect(measurement.celsius, 36.35);
      expect(measurement.timestamp, DateTime(2026, 2, 2, 6, 45, 14));
    });

    test('rejects a record of the wrong length', () {
      expect(
        () => parseMeasurementRecord([0x06, 0x33, 0x0e]),
        throwsFormatException,
      );
    });

    test('rejects a record whose frame markers do not match', () {
      final misframed = [
        0x06, 0x33, 0x0e, 0x00, 0x00, 0xea, 0x07, // byte 4 should be 0xfe
        0x02, 0x02, 0x06, 0x2d, 0x0e, 0x06,
      ];

      expect(() => parseMeasurementRecord(misframed), throwsFormatException);
    });
  });

  group('buildCurrentTimePayload', () {
    test('encodes a time in the Current Time Service format', () {
      // Protocol reference: 2026-08-29 03:13:04, a Saturday.
      final payload = buildCurrentTimePayload(DateTime(2026, 8, 29, 3, 13, 4));

      expect(payload, [
        0xea, 0x07, // year 2026, little-endian
        0x08, // month
        0x1d, // day 29
        0x03, // hour
        0x0d, // minute 13
        0x04, // second
        0x06, // day of week: Saturday
        0x00, // fractions256 (no milliseconds)
        0x01, // adjust reason: manual update
      ]);
    });
  });
}
