# Rise - Fertility Tracker

Rise is a privacy-first symptothermal fertility tracker built around basal body
temperature (BBT) thermometers whose original vendor app has been discontinued.
When a manufacturer drops support for a device, a working thermometer becomes
e-waste even though the hardware is fine. Rise keeps those devices useful: it
talks to them directly over Bluetooth Low Energy, so the data - and the device -
stay yours.

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
