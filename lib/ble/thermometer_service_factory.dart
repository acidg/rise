import 'package:flutter/foundation.dart';

import 'ovy_thermometer_service.dart';
import 'thermometer_service.dart';

/// Return the [ThermometerService] appropriate for the current platform: the
/// real BLE implementation on Android and iOS, and the fake everywhere else
/// (web, desktop, tests) where BLE is unavailable or view-only.
ThermometerService createThermometerService() {
  if (kIsWeb) {
    return FakeThermometerService();
  }
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
      return OvyThermometerService();
    default:
      return FakeThermometerService();
  }
}
