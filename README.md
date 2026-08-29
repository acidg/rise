# Rise - Fertility Tracker

Rise is a privacy-first symptothermal fertility tracker built around the Ovy
OT35, a Bluetooth basal body temperature (BBT) thermometer whose vendor app has
raised its minimum Android version beyond what many working phones can run. The
app is still maintained, but after the device's certification as a medical
product it now requires a recent Android release, so users on older but perfectly
capable phones are cut off. When that happens a working thermometer becomes
e-waste even though both it and the phone are fine. Rise keeps the OT35 useful:
it talks to the device directly over Bluetooth Low Energy, so the data - and the
device - stay yours.

## What it does

- Reads measurements directly from the thermometer over BLE (no vendor cloud).
- Charts basal temperature alongside the other symptothermal signs (cervical
  mucus, cervix position, bleeding, pain, mood, libido, intercourse, notes).
- Applies the Sensiplan symptothermal rules to mark the fertile window: mucus and
  calendar open it, the temperature shift (with the coverline / three-over-six
  rule) confirms and closes it.
- Lets you tap any day to review and edit its details.

## Privacy

Rise is local-first: the on-device database is the source of truth and the app
works fully offline. Optional sync is designed to be end-to-end encrypted, so
whoever stores the ciphertext never sees the health data. Your data stays under
your control.

## Platforms

- **Android** - primary target, full BLE sync.
- **iOS** - supported target (build requires macOS + Xcode).
- **Web** - view and manual entry only; browsers cannot do the BLE sync the
  device needs (iOS Safari has no Web Bluetooth at all).

## Development

Requires the Flutter SDK (stable channel).

```
flutter pub get      # fetch dependencies
flutter analyze      # static analysis
flutter test         # unit and widget tests
flutter run          # run on a connected device or emulator
```

The domain logic (models and the Sensiplan rule engine) is pure Dart under
`lib/domain/` with no Flutter dependency, so it runs and tests fast in isolation.

## Disclaimer

Rise is an independent, community-built project. It is not affiliated with,
endorsed by, sponsored by, or otherwise connected to Ovy GmbH in any way. "Ovy"
and any related names or trademarks belong to their respective owners and are
used here only to identify the thermometer the app works with. Rise is not a
medical device and makes no medical claims; the official vendor app is the only
certified medical product for this hardware.

## License

Rise is free software licensed under the GNU General Public License v3.0. You
may redistribute and modify it under the terms of that license; it comes with no
warranty. See [LICENSE](LICENSE) for the full text.

Copyright (C) 2026 Rise contributors
