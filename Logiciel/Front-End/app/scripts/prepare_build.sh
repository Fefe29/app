#!/usr/bin/env bash
# prepare_build.sh - Prepare Kornog project for platform-specific builds
# Handles platform-specific plugin constraints (e.g., audioplayers_linux on Linux)
#
# Usage:
#   scripts/prepare_build.sh android  # Prepare for Android build
#   scripts/prepare_build.sh linux    # Prepare for Linux build (removes audioplayers_linux)
#   scripts/prepare_build.sh ios      # Prepare for iOS build
#   scripts/prepare_build.sh windows  # Prepare for Windows build
#
# After running this script, you can build normally:
#   flutter run -d android
#   flutter build apk --release
#   flutter run -d linux
#   etc.

set -e

# Get the script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Validate target argument
if [ -z "$1" ]; then
  echo "Usage: $0 <target>"
  echo ""
  echo "Targets:"
  echo "  android   - Prepare for Android build (no changes needed, just pub get)"
  echo "  ios       - Prepare for iOS build (no changes needed, just pub get)"
  echo "  windows   - Prepare for Windows build (no changes needed, just pub get)"
  echo "  linux     - Prepare for Linux build (removes audioplayers_linux plugin)"
  echo "  web       - Prepare for Web build (no changes needed, just pub get)"
  echo ""
  exit 1
fi

TARGET="$1"

# Validate target
case "$TARGET" in
  android|ios|windows|linux|web|macos)
    ;;
  *)
    echo "❌ Unknown target: $TARGET"
    echo "Valid targets: android, ios, windows, linux, web, macos"
    exit 1
    ;;
esac

cd "$PROJECT_ROOT"

echo "📦 Running flutter pub get for target: $TARGET..."
flutter pub get

# Platform-specific preparations
if [ "$TARGET" = "linux" ]; then
  GENERATED="$PROJECT_ROOT/linux/flutter/generated_plugins.cmake"
  BACKUP="$GENERATED.bak"
  
  if [ -f "$GENERATED" ]; then
    echo "🔧 Removing audioplayers_linux from Linux build (system GStreamer not available)..."
    
    # Create backup
    cp "$GENERATED" "$BACKUP"
    
    # Remove the audioplayers_linux line from the plugin list
    # This prevents CMake from trying to link against the unavailable GStreamer library
    sed '/audioplayers_linux/d' "$BACKUP" > "$GENERATED"
    
    echo "✅ Patched $GENERATED"
    echo "   (Backup saved to $GENERATED.bak)"
  else
    echo "⚠️  $GENERATED not found yet. It will be generated during the build."
    echo "   If the build fails with GStreamer errors, run this script again after first build."
  fi
elif [ "$TARGET" = "android" ] || [ "$TARGET" = "ios" ] || [ "$TARGET" = "windows" ] || [ "$TARGET" = "web" ] || [ "$TARGET" = "macos" ]; then
  BACKUP="$PROJECT_ROOT/linux/flutter/generated_plugins.cmake.bak"
  GENERATED="$PROJECT_ROOT/linux/flutter/generated_plugins.cmake"
  
  # If there's a backup from a previous Linux build, restore it
  if [ -f "$BACKUP" ]; then
    echo "🔄 Restoring $GENERATED from backup (was prepared for Linux build)..."
    mv "$BACKUP" "$GENERATED"
  fi
  
  echo "✅ Build preparation complete for $TARGET"
else
  echo "✅ Build preparation complete for $TARGET"
fi

echo ""
echo "🚀 Ready to build!"
echo "   For Android:  flutter run -d android"
echo "                 flutter build apk --release"
echo "   For Linux:    flutter run -d linux"
echo "   For iOS:      flutter run -d ios"
echo "   For Windows:  flutter run -d windows"
echo ""
