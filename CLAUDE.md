# Rise app

Flutter app for the Ovy OT35 thermometer.

## Building and deploying to a device

- The toolchain (JDK 17, Android SDK, working `adb`, flutter) comes from the flake
  dev shell. Run build/deploy commands through `direnv exec .` so they use it.
  The bare NixOS environment cannot run the SDK's `adb` or find Java.
- Always **build then install**. Never deploy with `flutter install` alone: it does
  not compile, it only pushes the existing `build/app/outputs/flutter-apk/app-release.apk`,
  so it can silently ship a stale artifact from an earlier build.

  ```
  direnv exec . flutter build apk --release
  direnv exec . adb install -r build/app/outputs/flutter-apk/app-release.apk
  ```

  Confirm Gradle actually ran (an `assembleRelease` task in the output) and check
  the APK timestamp before installing.
- Launcher icons are generated from `assets/icon/` via `flutter_launcher_icons`
  (`dart run flutter_launcher_icons`) into `android/app/src/main/res/`. A stale APK
  showing the default Flutter icon is a sign an old build was deployed.
