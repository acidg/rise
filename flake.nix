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
      # minSdk 24). Only the platform and build-tools the build actually needs are
      # included, to keep the download small. The NDK is omitted because the app
      # has no native code; add it here if a plugin ever ships native libraries.
      android = pkgs.androidenv.composeAndroidPackages {
        platformVersions = [ "36" ];
        buildToolsVersions = [ "36.0.0" ];
        includeEmulator = false;
        includeSystemImages = false;
        includeNDK = false;
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
        '';
      };
    };
}
