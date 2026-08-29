import 'measurement.dart';

/// Vendor BLE identifiers for the Ovy OT35. Characteristics are always addressed
/// by UUID, and devices are recognised by name plus the custom service, never by
/// a hardcoded address, so any unit can be paired.
class OvyGatt {
  OvyGatt._();

  static const String advertisedName = 'Ovy OT35';
  static const String customService = 'fff0';
  static const String dataOut = 'fff1'; // measurement records (indicate)
  static const String dataOut2 = 'fff2'; // secondary data channel (indicate)
  static const String command = 'fff3'; // write, e.g. 0x01 = sync acknowledge
  static const String control = 'fff4'; // write 00 03 = request history
  static const String batteryService = '180f';
  static const String batteryLevel = '2a19';
  static const String currentTime = '2a2b';

  /// Command written to [control] to request the stored history.
  static const List<int> requestHistory = [0x00, 0x03];

  /// Command written to [command] to acknowledge a completed sync.
  static const List<int> acknowledge = [0x01];
}

/// Length in bytes of a measurement record indication.
const int kMeasurementRecordLength = 13;

const int _frameMarker = 0x06;
const int _midMarker = 0xfe;

/// Parse a 13-byte measurement record indication from characteristic `fff1`.
///
/// Layout (little-endian): byte 0 `0x06` marker, bytes 1-2 temperature in
/// centi-Celsius, byte 3 flags, byte 4 `0xfe` marker, bytes 5-6 year, byte 7
/// month, byte 8 day, byte 9 hour, byte 10 minute, byte 11 second, byte 12
/// `0x06` marker. Throws [FormatException] if the length or frame markers are
/// wrong, so a truncated or misframed indication is never decoded into a bogus
/// reading.
Measurement parseMeasurementRecord(List<int> record) {
  if (record.length != kMeasurementRecordLength) {
    throw FormatException(
      'expected $kMeasurementRecordLength bytes, got ${record.length}',
    );
  }
  if (record[0] != _frameMarker ||
      record[4] != _midMarker ||
      record[12] != _frameMarker) {
    throw const FormatException('record frame markers do not match');
  }

  final centiCelsius = record[1] | (record[2] << 8);
  final year = record[5] | (record[6] << 8);
  final timestamp = DateTime(
    year,
    record[7],
    record[8],
    record[9],
    record[10],
    record[11],
  );
  return Measurement(timestamp: timestamp, celsius: centiCelsius / 100);
}

/// Build the 10-byte Current Time Service payload (`0x2a2b`) for [time], written
/// on connect so new measurements are timestamped by the device correctly.
///
/// Year is little-endian; day-of-week uses 1=Monday..7=Sunday, matching Dart's
/// [DateTime.weekday]. The final byte is the adjust-reason flag (manual update).
List<int> buildCurrentTimePayload(DateTime time) {
  final year = time.year;
  return <int>[
    year & 0xff,
    (year >> 8) & 0xff,
    time.month,
    time.day,
    time.hour,
    time.minute,
    time.second,
    time.weekday,
    (time.millisecond * 256 ~/ 1000) & 0xff,
    0x01,
  ];
}
