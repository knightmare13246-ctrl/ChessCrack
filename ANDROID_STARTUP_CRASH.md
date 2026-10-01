# Android Cold-Start Crash Investigation & Root-Cause Analysis

## Summary

This report documents the root-cause analysis and reproduction of the cold-start startup crashes reported on modern Android devices, tablets, and x86_64 environments when downloading release packages from GitHub Releases.

---

## 1. Environment Details

- **Test Device 1 (Physical)**: Samsung Galaxy M10 (`SM-M105F`)
  - **Android Version**: 10 (Q)
  - **API Level**: 29
  - **Device ABI**: `armeabi-v7a`
  - **Supported ABIs**: `armeabi-v7a`, `armeabi`
- **Test Device 2 (Emulator/Tablet)**: Android 14 Google APIs (`sdk_gphone64_x86_64`)
  - **Android Version**: 14 (UpsideDownCake)
  - **API Level**: 34
  - **Device ABI**: `x86_64`
  - **Supported ABIs**: `x86_64`, `arm64-v8a`
- **Target OS Range**: Android 8.0 (API 24) through Android 16 (API 36)
- **Flutter Version**: 3.24+ (Dart 3.5+)
- **Gradle Version**: 8.7+
- **Android Gradle Plugin (AGP)**: 8.5+
- **compileSdk**: 36
- **targetSdk**: 35
- **minSdk**: 24

---

## 2. Observed Crashes & Root Causes

### Crash #1: `Error type 3: Activity class {org.chesscrack.app/org.chesscrack.app.MainActivity} does not exist` on x86_64 Tablets and Emulators

#### Observed Crash
When installing `app-x86_64-release.apk` on an x86_64 Android environment (including tablets, Chromebooks, and emulators), the app fails to start immediately:
```text
Starting: Intent { cmp=org.chesscrack.app/.MainActivity }
Error type 3
Error: Activity class {org.chesscrack.app/org.chesscrack.app.MainActivity} does not exist.
```

#### Evidence
1. Running `aapt2 dump badging build/app/outputs/flutter-apk/app-x86_64-release.apk` revealed that the APK contained **zero** native libraries (`native-code:` attribute was completely absent from AAPT output).
2. Running `tar -tf build/app/outputs/flutter-apk/app-x86_64-release.apk | grep lib/` returned 0 lines. `libflutter.so`, `libapp.so`, and all native shared libraries were missing.
3. During Android `LoadedApk` class loading, the Flutter embedding attempts to link the Flutter engine. Because `libflutter.so` was absent, `UnsatisfiedLinkError` was thrown during `MainActivity` class verification, which Android surfaces to the shell as `Activity class does not exist`.

#### Root Cause
In `android/app/build.gradle.kts`:
```kotlin
packaging {
    jniLibs {
        excludes += listOf("lib/x86/**", "lib/x86_64/**", "**/libVkLayer_khronos_validation.so")
    }
}
```
The explicit exclusion of `"lib/x86_64/**"` stripped Flutter's AOT runtime engine from all x86_64 builds.

---

### Crash #2: `INSTALL_FAILED_NO_MATCHING_ABIS` / Immediate Fatal Exit on 64-Bit Android 14/15/16 Devices

#### Observed Crash
Users downloading APKs from GitHub on modern 64-bit-only devices (such as Google Pixel Tablet, Pixel 7/8/9, Galaxy Tab S9 running Android 14, 15, or 16) who downloaded `app-armeabi-v7a-release.apk` encountered:
```text
Failure [INSTALL_FAILED_NO_MATCHING_ABIS: Failed to extract native libraries, res=-113]
```
Or on devices without a 32-bit zygote daemon, launching the app triggered immediate termination with:
`ChessCrack keeps stopping` / `ChessCrack stopped due to internal error`.

#### Evidence
1. Android 14+ on modern 64-bit architectures has completely dropped the 32-bit runtime (`ro.product.cpu.abilist` contains only `arm64-v8a`).
2. Sideloading a 32-bit (`armeabi-v7a`) split APK on a 64-bit-only hardware platform causes the OS loader to abort because no 32-bit zygote process exists.
3. Because GitHub Releases only hosted architecture-split APKs with technical ABI filenames (`app-armeabi-v7a-release.apk`, `app-arm64-v8a-release.apk`, `app-x86_64-release.apk`), users unfamiliar with CPU architectures selected the wrong artifact.

#### Root Cause
Missing a single, self-contained Universal Release APK (`ChessCrack-universal-v1.0.0.apk`) containing multi-architecture native libraries (`arm64-v8a`, `armeabi-v7a`, and `x86_64`) that installs and runs seamlessly on any device.

---

### Crash #3: Incompatible Desktop Linux Executable Resolution on Android x86_64

#### Observed Behavior
In `EngineDownloadService._resolveStockfishUrl()`:
```dart
} else if (abi == 'x86_64') {
  return 'https://github.com/official-stockfish/Stockfish/releases/download/sf_19/stockfish-linux-x86-64-universal.tar.gz';
}
```
The download service attempted to download a glibc-linked desktop Linux x86_64 binary onto an Android x86_64 system. Android uses Bionic libc, so attempting to execute a desktop Linux binary fails with linkage errors or crashes.

#### Root Cause
Stockfish does not publish an official Android x86_64 native build. The app must detect when an engine build is unavailable for the host ABI, mark it as `unsupported`, prevent downloading, and display:
`"Engine unavailable for this device architecture."`

---

## 3. Files Involved

1. `android/app/build.gradle.kts`:
   - Remove `"lib/x86_64/**"` from `packaging.jniLibs.excludes`.
   - Update `targetSdk` to modern Android 35 while preserving compatibility flags.
2. `lib/services/engine_download_service.dart`:
   - Add explicit ABI support check: mark Android x86_64 Stockfish as unsupported rather than attempting to download desktop Linux binaries.
3. `lib/ui/screens/chess_analysis_screen.dart`:
   - Guard `_initEngineWithNativeCheck()` so cold start does NOT attempt to start a native engine when no engine is installed.
   - Set status cleanly to `"Stockfish not installed. Tap Engine to download."` without entering an error state.
4. `lib/main.dart` & `android/app/src/main/res/values/styles.xml`:
   - Configure transparent system navigation bar for Android 15/16 edge-to-edge compliance.

---

## 4. Fix Implementation Plan

1. **Gradle Packaging**: Keep only `"lib/x86/**"` in `jniLibs.excludes` (retaining full `x86_64` support).
2. **Build Universal APK**: Build `ChessCrack-universal-v1.0.0.apk` containing `arm64-v8a`, `armeabi-v7a`, and `x86_64`.
3. **Build Per-ABI Splits**: Produce cleanly named split APKs (`ChessCrack-arm64-v8a-v1.0.0.apk`, `ChessCrack-armeabi-v7a-v1.0.0.apk`, `ChessCrack-x86_64-v1.0.0.apk`).
4. **Cold-Start Guard**: Ensure zero engine startup calls occur until the user explicitly installs an engine.

---

## 5. Verification Checklist

- [x] ELF alignment check with `llvm-readelf`: verified 16-KB / 64-KB alignment on all packaged `.so` libraries.
- [ ] Clean install of Universal APK on physical 32-bit device (`SM-M105F`).
- [ ] Clean install of Universal APK on 64-bit Android 14/15/16 environment.
- [ ] Verification of tablet landscape/portrait layout without crashes or overflows.
