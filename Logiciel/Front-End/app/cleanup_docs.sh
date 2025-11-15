#!/bin/bash

# Script de nettoyage de la documentation
# Supprime les fichiers .md obsolètes et archive les anciens

set -e

cd "$(dirname "$0")"

echo "🧹 Nettoyage de la documentation KORNOG..."
echo ""

# Créer les dossiers d'archive
echo "📁 Création des dossiers d'archive..."
mkdir -p ARCHIVE/Fixes
mkdir -p ARCHIVE/Changelogs
mkdir -p ARCHIVE/Rapports
mkdir -p ARCHIVE/Concepts

# Archiver les fichiers de fixes (historique)
echo "📦 Archivage des fixes..."
for file in TELEMETRY_COMPLETE_FIX_SUMMARY.md TELEMETRY_FIX_BLOCKING_ISSUE.md \
            TELEMETRY_FIX_EMPTY_SESSIONS.md TELEMETRY_FIX_GZIP_CODEC.md \
            FIX_STATEPROVIDER_ERROR.md; do
    if [ -f "$file" ]; then
        mv "$file" "ARCHIVE/Fixes/"
        echo "  ✓ Archivé: $file"
    fi
done

# Archiver les changelogs (historique)
echo "📦 Archivage des changelogs..."
for file in CHANGELOG_V3.md CHANGELOG_TELEMETRY.md REFACTORING_V3_SUMMARY.md \
            REFACTORING_V3_1_SUMMARY.md; do
    if [ -f "$file" ]; then
        mv "$file" "ARCHIVE/Changelogs/"
        echo "  ✓ Archivé: $file"
    fi
done

# Archiver les anciens rapports (historique)
echo "📦 Archivage des anciens rapports..."
for file in TELEMETRY_ANALYSIS_INTEGRATION.md INTEGRATION_COMPLETE.md \
            TELEMETRY_PERSISTENCE_COMPLETE.md; do
    if [ -f "$file" ]; then
        mv "$file" "ARCHIVE/Rapports/"
        echo "  ✓ Archivé: $file"
    fi
done

# Archiver les anciens concepts (à revoir)
echo "📦 Archivage des anciens concepts..."
for file in ADVANCED_ANALYSIS_ARCHITECTURE.md ADVANCED_ANALYSIS_GUIDE.md \
            ADVANCED_ANALYSIS_QUICK_ACCESS.md UI_ARCHITECTURE_V3.md; do
    if [ -f "$file" ]; then
        mv "$file" "ARCHIVE/Concepts/"
        echo "  ✓ Archivé: $file"
    fi
done

# Supprimer les fichiers complètement obsolètes
echo "🗑️  Suppression des fichiers obsolètes..."
rm -f TELEMETRY_SYSTEM_INDEX.md && echo "  ✓ Supprimé: TELEMETRY_SYSTEM_INDEX.md"
rm -f TELEMETRY_INDEX.md && echo "  ✓ Supprimé: TELEMETRY_INDEX.md"
rm -f TELEMETRY_STORAGE_GUIDE.md && echo "  ✓ Supprimé: TELEMETRY_STORAGE_GUIDE.md"
rm -f TELEMETRY_STORAGE_VISUAL.md && echo "  ✓ Supprimé: TELEMETRY_STORAGE_VISUAL.md"
rm -f TELEMETRY_INTEGRATION_CHECKLIST.md && echo "  ✓ Supprimé: TELEMETRY_INTEGRATION_CHECKLIST.md"
rm -f TELEMETRY_GETTING_STARTED.md && echo "  ✓ Supprimé: TELEMETRY_GETTING_STARTED.md"
rm -f IMPLEMENTATION_CHECKLIST.md && echo "  ✓ Supprimé: IMPLEMENTATION_CHECKLIST.md"
rm -f NMEA_ARCHITECTURE.md && echo "  ✓ Supprimé: NMEA_ARCHITECTURE.md"
rm -f NMEA_AUTO_DISCOVERY_COMPLETE.md && echo "  ✓ Supprimé: NMEA_AUTO_DISCOVERY_COMPLETE.md"
rm -f NMEA_CONFIG_EXAMPLES.md && echo "  ✓ Supprimé: NMEA_CONFIG_EXAMPLES.md"
rm -f NMEA_INTEGRATION_GUIDE.md && echo "  ✓ Supprimé: NMEA_INTEGRATION_GUIDE.md"
rm -f REGATTA_SOUND_SEQUENCE.md && echo "  ✓ Supprimé: REGATTA_SOUND_SEQUENCE.md"
rm -f SOUNDS_IMPLEMENTATION.md && echo "  ✓ Supprimé: SOUNDS_IMPLEMENTATION.md"
rm -f SOUNDS_STATUS.md && echo "  ✓ Supprimé: SOUNDS_STATUS.md"
rm -f INDEX.md && echo "  ✓ Supprimé: INDEX.md"

echo ""
echo "✅ Nettoyage terminé!"
echo ""
echo "📊 Résumé:"
echo "  - 25+ fichiers archivés ou supprimés"
echo "  - Archive créée dans: ARCHIVE/"
echo "  - Documentation essentielle conservée"
echo ""
echo "📚 Fichiers pertinents conservés:"
echo "  ✓ 00_LIRE_D_ABORD.md"
echo "  ✓ QUICK_REFERENCE.md"
echo "  ✓ TELEMETRY_QUICK_START.md"
echo "  ✓ TELEMETRY_FINAL_REPORT.md"
echo "  ✓ TELEMETRY_ONE_PAGE.md"
echo "  ✓ SESSION_SELECTION_SYSTEM.md"
echo "  ✓ TELEMETRY_DIAGNOSTIC_LOGS.md"
echo "  ✓ CHART_INTEGRATION_GUIDE.md"
echo "  ✓ TELEMETRY_UI_IMPROVEMENTS.md"
echo "  ✓ WIND_ARCHITECTURE.md"
echo "  ✓ SOUND_ALARMS_GUIDE.md"
echo "  ✓ NMEA_QUICK_START.md"
echo "  ✓ NMEA_README.md"
echo "  ✓ SOUNDS_FINAL_REPORT.md"
echo "  ✓ SOUNDS_FINAL_SUMMARY.md"
echo "  ✓ DOCUMENTATION_INDEX.md (nouveau)"
echo ""
