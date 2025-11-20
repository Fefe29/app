# Build Scripts for Kornog

This directory contains helper scripts for platform-specific builds.

## Quick Start

### Build and install on Android (one command)
```bash
./scripts/build_and_install_android.sh
# or with specific device
./scripts/build_and_install_android.sh 9XSSAUY5FIJV7D7P
# or release build
./scripts/build_and_install_android.sh --release
```

This script automatically:
1. Prepares the Android build environment
2. Builds the APK
3. Finds your Android device (or uses specified one)
4. Installs the APK on device
5. Shows instructions to run the app

## `prepare_build.sh`

**Purpose**: Prepare the project for platform-specific builds by handling platform-dependent plugin constraints.

### Why is this needed?

The Kornog app uses the `audioplayers` package for sound playback on Android/iOS/Windows. However, on Linux, `audioplayers` depends on GStreamer libraries which may not be available in all environments. The `prepare_build.sh` script automates the setup to prevent build failures.

### Usage

Run before building for any platform:

```bash
# For Android
scripts/prepare_build.sh android
flutter run -d android
# or build APK (see build_and_install_android.sh for automatic install)
flutter build apk --release

# For Linux
scripts/prepare_build.sh linux
flutter run -d linux

# For iOS
scripts/prepare_build.sh ios
flutter run -d ios

# For Windows
scripts/prepare_build.sh windows
flutter run -d windows

# For Web
scripts/prepare_build.sh web
flutter run -d web
```

### What does it do?

1. **Runs `flutter pub get`** to fetch dependencies for all platforms.
2. **For Linux builds**: Removes `audioplayers_linux` from the CMake plugin list (`linux/flutter/generated_plugins.cmake`). This prevents the build from trying to compile the Linux audio plugin, which requires GStreamer.
3. **For other platforms**: Restores the original plugin list if it was previously modified for a Linux build.

### How it works

- When you run `scripts/prepare_build.sh linux`, the script creates a backup of `generated_plugins.cmake` and removes the `audioplayers_linux` entry.
- When you run `scripts/prepare_build.sh android` (or another non-Linux target) afterward, the backup is restored.
- This ensures a single `pubspec.yaml` can work across all platforms without manual edits.

## `build_and_install_android.sh`

**Purpose**: Build Flutter APK and automatically install on Android device in one command.

### Quick Usage

```bash
# Build debug APK and install on first device found
./scripts/build_and_install_android.sh

# Build debug APK and install on specific device
./scripts/build_and_install_android.sh 9XSSAUY5FIJV7D7P

# Build release APK and install
./scripts/build_and_install_android.sh --release

# Build release APK and install on specific device
./scripts/build_and_install_android.sh --release 9XSSAUY5FIJV7D7P

# Just install (if APK already built)
./scripts/build_and_install_android.sh --install-only 9XSSAUY5FIJV7D7P
```

### What does it do?

1. Runs `prepare_build.sh android` to set up the build environment
2. Builds the APK (debug by default, release with `--release`)
3. Auto-detects your Android device (or uses specified device ID)
4. Installs the APK on the device with `-r` flag (replace if exists)
5. Shows you how to run the app with `flutter run`

### Finding Your Device ID

Connected devices are shown with `adb devices`. The script will also prompt you if multiple devices are found.

```bash
# List all connected devices
adb devices -l
```

### Examples

```bash
# Development workflow: quick build and test
./scripts/build_and_install_android.sh

# Release build for testing
./scripts/build_and_install_android.sh --release

# Specific device (tablet 9XSSAUY5FIJV7D7P)
./scripts/build_and_install_android.sh 9XSSAUY5FIJV7D7P

# Release on tablet
./scripts/build_and_install_android.sh --release 9XSSAUY5FIJV7D7P

# Rebuild and reinstall (just APK compilation, skip pub get)
./scripts/build_and_install_android.sh --install-only
```

### Platform Support

| Platform | Supported | Notes |
|----------|-----------|-------|
| Android  | ✅ Yes    | Audio playback via audioplayers |
| iOS      | ✅ Yes    | Audio playback via audioplayers |
| Windows  | ✅ Yes    | Audio playback via audioplayers |
| Linux    | ✅ Yes    | No audio (uses SoundPlayerStub) |
| macOS    | ✅ Yes    | No audio (uses SoundPlayerStub) |
| Web      | ✅ Yes    | No audio (uses SoundPlayerStub) |

### Troubleshooting

**Q: The build still fails with GStreamer errors on Linux**

A: This may happen if `generated_plugins.cmake` is regenerated during the build process. Try:
1. Run the script again: `scripts/prepare_build.sh linux`
2. Clean the build: `flutter clean`
3. Run the script again: `scripts/prepare_build.sh linux`
4. Build: `flutter run -d linux`

**Q: I'm switching from Linux to Android and the build fails**

A: Make sure to run `scripts/prepare_build.sh android` before building for Android. The script restores the plugin configuration.

**Q: Can I edit `pubspec.yaml` freely?**

A: Yes! Changes to `pubspec.yaml` are preserved across all platform builds. The script only manages the CMake plugin configuration, not `pubspec.yaml`.

### Files Modified

- `linux/flutter/generated_plugins.cmake` - Modified (and backed up as `.bak`) when preparing for Linux builds
- `pubspec.yaml` - **Not modified** (stays the same across all platforms)
- All platform-specific code (Android, iOS, etc.) - **Not modified**

## CI/CD Integration

For automated builds in CI/CD pipelines, you can use the scripts:

```yaml
# GitHub Actions example
- name: Build and install Android APK
  run: ./scripts/build_and_install_android.sh --release 9XSSAUY5FIJV7D7P

# Or just prepare and build manually
- name: Prepare Android build
  run: ./scripts/prepare_build.sh android

- name: Build APK
  run: flutter build apk --release
```
