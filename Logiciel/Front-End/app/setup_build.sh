#!/bin/bash
# Script pour configurer le build selon la plateforme cible
# Usage: ./setup_build.sh [linux|android]

set -e

PLATFORM=${1:-linux}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PUBSPEC="$SCRIPT_DIR/pubspec.yaml"

echo "🔧 Configuration du build pour: $PLATFORM"

if [ "$PLATFORM" = "linux" ]; then
    echo "📝 Commentant audioplayers pour build Linux..."
    # Commenter audioplayers
    sed -i 's/^  audioplayers: \^6.0.0/  # audioplayers: ^6.0.0 # Disabled for Linux (GStreamer)/' "$PUBSPEC"
    
elif [ "$PLATFORM" = "android" ]; then
    echo "📝 Activant audioplayers pour build Android..."
    # Décommenter audioplayers
    sed -i 's/^  # audioplayers: \^6.0.0 # Disabled for Linux/  audioplayers: ^6.0.0/' "$PUBSPEC"
fi

echo "✅ Build configuré pour $PLATFORM"
echo ""
echo "Exécute maintenant:"
if [ "$PLATFORM" = "linux" ]; then
    echo "  flutter run -d linux"
elif [ "$PLATFORM" = "android" ]; then
    echo "  flutter run -d android"
fi
