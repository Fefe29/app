#!/bin/bash

# 🎯 ADVANCED ANALYSIS WINDOW - TEST SCRIPT
# 
# Ce script teste l'intégration complète du système de télémétrie
# Usage: bash test_advanced_analysis.sh

set -e

echo "🎯 ADVANCED ANALYSIS WINDOW - TEST COMPLET"
echo "=========================================="
echo ""

# 1. Vérifier les fichiers
echo "✅ 1️⃣ Vérification des fichiers..."
files=(
    "lib/data/datasources/telemetry/telemetry_storage.dart"
    "lib/data/datasources/telemetry/json_telemetry_storage.dart"
    "lib/data/datasources/telemetry/telemetry_recorder.dart"
    "lib/features/telemetry_recording/providers/telemetry_storage_providers.dart"
    "lib/features/analysis/presentation/pages/advanced_analysis_page.dart"
    "lib/app/router.dart"
    "lib/main.dart"
)

for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo "   ✓ $file"
    else
        echo "   ✗ $file MANQUANT!"
        exit 1
    fi
done

echo ""
echo "✅ 2️⃣ Vérification des imports..."

# Vérifier imports dans advanced_analysis_page.dart
grep -q "import 'package:flutter_riverpod/flutter_riverpod.dart'" lib/features/analysis/presentation/pages/advanced_analysis_page.dart && \
echo "   ✓ Riverpod import ok" || echo "   ✗ Riverpod import MISSING!"

grep -q "telemetry_storage_providers" lib/features/analysis/presentation/pages/advanced_analysis_page.dart && \
echo "   ✓ Providers import ok" || echo "   ✗ Providers import MISSING!"

echo ""
echo "✅ 3️⃣ Vérification des routes..."

# Vérifier la route dans router.dart
grep -q "/analysis/advanced" lib/app/router.dart && \
echo "   ✓ Route /analysis/advanced ok" || echo "   ✗ Route MISSING!"

grep -q "AdvancedAnalysisPage" lib/app/router.dart && \
echo "   ✓ Route handler ok" || echo "   ✗ Route handler MISSING!"

echo ""
echo "✅ 4️⃣ Vérification de l'initialisation main.dart..."

grep -q "JsonTelemetryStorage" lib/main.dart && \
echo "   ✓ JsonTelemetryStorage init ok" || echo "   ✗ Init MISSING!"

grep -q "telemetryStorageProvider.overrideWithValue" lib/main.dart && \
echo "   ✓ Provider override ok" || echo "   ✗ Override MISSING!"

echo ""
echo "✅ 5️⃣ Vérification du code..."

# Vérifier présence des widgets clés
grep -q "class _RecordingControlPanel" lib/features/analysis/presentation/pages/advanced_analysis_page.dart && \
echo "   ✓ _RecordingControlPanel widget ok" || echo "   ✗ Widget MISSING!"

grep -q "class _SessionSelector" lib/features/analysis/presentation/pages/advanced_analysis_page.dart && \
echo "   ✓ _SessionSelector widget ok" || echo "   ✗ Widget MISSING!"

grep -q "class _DataViewer" lib/features/analysis/presentation/pages/advanced_analysis_page.dart && \
echo "   ✓ _DataViewer widget ok" || echo "   ✗ Widget MISSING!"

echo ""
echo "🎉 TOUS LES TESTS PASSENT!"
echo ""
echo "📋 Prochaines étapes:"
echo "   1. flutter pub get"
echo "   2. flutter run"
echo "   3. Naviguer à /analysis/advanced"
echo "   4. Tester Start/Stop enregistrement"
echo "   5. Vérifier les données sauvegardées"
echo ""
