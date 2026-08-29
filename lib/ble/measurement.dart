/// A single basal body temperature measurement read from the thermometer.
class Measurement {
  /// When the measurement was taken, from the device's real-time clock.
  final DateTime timestamp;

  /// Temperature in degrees Celsius.
  final double celsius;

  const Measurement({required this.timestamp, required this.celsius});
}
