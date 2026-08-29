{
  description = "Rise - Fertility Tracker Android development environment";

  inputs.nixpkgs.url = "nixpkgs";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
          android_sdk.accept_license = true;
        };
      };

      # Versions match the Flutter 3.44 Android defaults (compileSdk/targetSdk 36,
      # minSdk 24, NDK 28.2.13676358). AGP 9 requires a complete NDK to be present
      # for any app build (it validates/strips even Flutter's prebuilt .so files),
      # so it must be included even though this app has no native code of its own.
      android = pkgs.androidenv.composeAndroidPackages {
        platformVersions = [ "36" ];
        buildToolsVersions = [ "36.0.0" ];
        includeEmulator = false;
        includeSystemImages = false;
        includeNDK = true;
        ndkVersions = [ "28.2.13676358" ];
        # Flutter's Gradle plugin points AGP at an empty CMakeLists.txt purely to
        # force the NDK to be present (see forceNdkDownload). It builds nothing but
        # still needs a CMake binary at AGP's default version.
        cmakeVersions = [ "3.22.1" ];
      };

      sdk = "${android.androidsdk}/libexec/android-sdk";
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        # Flutter itself comes from the user's environment; this shell only
        # supplies the JDK and the NixOS-patched Android SDK and adb that the
        # generic Google binaries cannot provide on NixOS.
        buildInputs = [
          pkgs.jdk17
          pkgs.android-tools
          android.androidsdk
        ];

        ANDROID_HOME = sdk;
        ANDROID_SDK_ROOT = sdk;
        JAVA_HOME = "${pkgs.jdk17}";

        shellHook = ''
          export PATH="$ANDROID_HOME/platform-tools:$PATH"
          # NixOS: point AGP at the patched aapt2 instead of the generic one it
          # would otherwise fetch from Maven.
          aapt2="$(ls -d "$ANDROID_HOME"/build-tools/*/aapt2 2>/dev/null | sort -V | tail -n1)"
          if [ -n "$aapt2" ]; then
            export GRADLE_OPTS="-Dorg.gradle.project.android.aapt2FromMavenOverride=$aapt2 ''${GRADLE_OPTS:-}"
          fi

          # Flutter's Android build includeBuild's the SDK's flutter_tools/gradle
          # directory, which AGP needs to write into. In the read-only Nix store
          # that fails, so expose a writable FLUTTER_ROOT: a symlink farm of the
          # real SDK where only that small gradle dir is a writable copy. The
          # Nix flutter wrapper honours a pre-set FLUTTER_ROOT.
          if command -v flutter >/dev/null 2>&1; then
            realsdk="$(cd "$(dirname "$(readlink -f "$(command -v flutter)")")/.." && pwd)"
            farm="$HOME/.cache/rise/flutter-writable"
            if [ "$(cat "$farm/.source" 2>/dev/null)" != "$realsdk" ]; then
              rm -rf "$farm"; mkdir -p "$farm"
              for p in "$realsdk"/* "$realsdk"/.[!.]*; do
                [ -e "$p" ] && ln -s "$p" "$farm/$(basename "$p")"
              done
              rm -f "$farm/packages"; mkdir -p "$farm/packages"
              for p in "$realsdk"/packages/*; do ln -s "$p" "$farm/packages/$(basename "$p")"; done
              rm -f "$farm/packages/flutter_tools"; mkdir -p "$farm/packages/flutter_tools"
              for p in "$realsdk"/packages/flutter_tools/*; do ln -s "$p" "$farm/packages/flutter_tools/$(basename "$p")"; done
              rm -f "$farm/packages/flutter_tools/gradle"
              cp -rL "$realsdk/packages/flutter_tools/gradle" "$farm/packages/flutter_tools/gradle"
              chmod -R u+w "$farm/packages/flutter_tools/gradle"
              echo "$realsdk" > "$farm/.source"
            fi
            export FLUTTER_ROOT="$farm"
          fi
        '';
      };
    };
}
