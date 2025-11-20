#!/usr/bin/env bash
# build_and_install_android.sh - Build APK and install on Android device
#
# Usage:
#   scripts/build_and_install_android.sh              # Build and install on first device found
#   scripts/build_and_install_android.sh 9XSSAUY5FIJV7D7P  # Build and install on specific device
#   scripts/build_and_install_android.sh --release    # Build release APK
#   scripts/build_and_install_android.sh --debug      # Build debug APK (default)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Parse arguments
BUILD_MODE="debug"
DEVICE_ID=""
INSTALL_ONLY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --release)
      BUILD_MODE="release"
      shift
      ;;
    --debug)
      BUILD_MODE="debug"
      shift
      ;;
    --install-only)
      INSTALL_ONLY=true
      shift
      ;;
    -*)
      echo "❌ Unknown option: $1"
      echo "Usage: $0 [--debug|--release] [--install-only] [DEVICE_ID]"
      exit 1
      ;;
    *)
      DEVICE_ID="$1"
      shift
      ;;
  esac
done

cd "$PROJECT_ROOT"

# Step 1: Prepare build
echo "🔧 Preparing Android build..."
./scripts/prepare_build.sh android

if [ "$INSTALL_ONLY" = false ]; then
  # Step 2: Build APK
  echo ""
  echo "🔨 Building $BUILD_MODE APK..."
  flutter build apk --${BUILD_MODE}
  
  if [ $? -ne 0 ]; then
    echo "❌ Build failed!"
    exit 1
  fi
  
  echo "✅ APK built successfully"
fi

# Step 3: Find device if not specified
if [ -z "$DEVICE_ID" ]; then
  echo ""
  echo "📱 Looking for Android devices..."
  DEVICES=$(adb devices -l | grep -v "^List" | grep -v "^$" | awk '{print $1}')
  DEVICE_COUNT=$(echo "$DEVICES" | wc -l)
  
  if [ "$DEVICE_COUNT" -eq 0 ]; then
    echo "❌ No Android devices found!"
    echo "Please connect an Android device or emulator."
    exit 1
  elif [ "$DEVICE_COUNT" -eq 1 ]; then
    DEVICE_ID=$(echo "$DEVICES" | head -1)
    echo "📱 Found device: $DEVICE_ID"
  else
    echo "📱 Found multiple devices:"
    echo "$DEVICES" | nl
    echo ""
    read -p "Select device (number or ID): " SELECTION
    if [[ "$SELECTION" =~ ^[0-9]+$ ]]; then
      DEVICE_ID=$(echo "$DEVICES" | sed -n "${SELECTION}p")
    else
      DEVICE_ID="$SELECTION"
    fi
  fi
fi

# Verify device
echo ""
echo "🔍 Verifying device connection..."
if ! adb -s "$DEVICE_ID" shell echo "OK" > /dev/null 2>&1; then
  echo "❌ Cannot connect to device: $DEVICE_ID"
  exit 1
fi

echo "✅ Connected to: $DEVICE_ID"

# Step 4: Find APK
APK_PATH=$(find "$PROJECT_ROOT/build/app/outputs/apk/${BUILD_MODE}" -name "app-*.apk" | tail -1)

if [ -z "$APK_PATH" ] || [ ! -f "$APK_PATH" ]; then
  # Try alternate path
  APK_PATH=$(find "$PROJECT_ROOT/build/app/outputs/apk" -name "*.apk" | tail -1)
fi

if [ -z "$APK_PATH" ] || [ ! -f "$APK_PATH" ]; then
  echo "❌ APK not found!"
  echo "Expected location: build/app/outputs/apk/${BUILD_MODE}/app-*.apk"
  exit 1
fi

echo ""
echo "📦 APK: $(basename "$APK_PATH")"
echo "   Size: $(du -h "$APK_PATH" | cut -f1)"

# Step 5: Install APK
echo ""
echo "📲 Installing on $DEVICE_ID..."
adb -s "$DEVICE_ID" install -r "$APK_PATH"

if [ $? -ne 0 ]; then
  echo "❌ Installation failed!"
  exit 1
fi

echo ""
echo "✨ Done!"
echo ""
echo "💡 To run the app on device:"
echo "   flutter run -d $DEVICE_ID"
echo ""
