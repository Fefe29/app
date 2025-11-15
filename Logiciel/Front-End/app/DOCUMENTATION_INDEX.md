# Documentation Index - KORNOG App

**Date de dernière mise à jour:** 15 novembre 2025

## 📋 Fichiers Pertinents & À Jour

### 🔴 Essentiels - À LIRE EN PRIORITÉ

1. **00_LIRE_D_ABORD.md** - Point d'entrée principal
2. **QUICK_REFERENCE.md** - Référence rapide des features

### 🟢 Télémétrie & Enregistrement (Actuellement Implémenté)

| Fichier | Description | Statut |
|---------|-------------|--------|
| `TELEMETRY_QUICK_START.md` | Guide de démarrage télémétrie | ✅ À jour (15 nov) |
| `TELEMETRY_FINAL_REPORT.md` | Rapport complet du système | ✅ À jour (14 nov) |
| `TELEMETRY_ONE_PAGE.md` | Résumé 1 page du système | ✅ À jour (14 nov) |
| `SESSION_SELECTION_SYSTEM.md` | Système de sélection des sessions | ✅ À jour (15 nov) |
| `TELEMETRY_DIAGNOSTIC_LOGS.md` | Logs diagnostiques | ✅ À jour (15 nov) |

### 🟢 Graphiques & Analyse

| Fichier | Description | Statut |
|---------|-------------|--------|
| `CHART_INTEGRATION_GUIDE.md` | Intégration des graphiques | ✅ À jour (15 nov) |
| `TELEMETRY_UI_IMPROVEMENTS.md` | Améliorations UI | ✅ À jour (15 nov) |
| `WIND_ARCHITECTURE.md` | Architecture du système de vent | ✅ À jour |

### 🟡 Son & Alarmes (Ancien - À Vérifier)

| Fichier | Description | Statut |
|---------|-------------|--------|
| `SOUND_ALARMS_GUIDE.md` | Guide alarmes sonores | 🟡 À mettre à jour |
| `SOUNDS_FINAL_SUMMARY.md` | Résumé son (ancien) | 🟡 Obsolète |

### 🟡 NMEA (Ancien - À Vérifier)

| Fichier | Description | Statut |
|---------|-------------|--------|
| `NMEA_QUICK_START.md` | Démarrage NMEA | 🟡 À vérifier |
| `NMEA_README.md` | Readme NMEA | 🟡 À vérifier |

### 🟠 Rapports de Bugs & Fixes (Historique)

Ces fichiers sont utiles pour comprendre les problèmes résolus mais ne sont pas essentiels:

- `TELEMETRY_COMPLETE_FIX_SUMMARY.md` - Résumé des fixes (archive)
- `TELEMETRY_FIX_BLOCKING_ISSUE.md` - Fix issue bloquant (archive)
- `TELEMETRY_FIX_EMPTY_SESSIONS.md` - Fix sessions vides (archive)
- `TELEMETRY_FIX_GZIP_CODEC.md` - Fix codec GZIP (archive)
- `FIX_STATEPROVIDER_ERROR.md` - Fix StateProvider (archive)

### 🟠 Logs & Changelogs (Historique)

- `CHANGELOG_V3.md` - Changelog V3
- `CHANGELOG_TELEMETRY.md` - Changelog télémétrie
- `REFACTORING_V3_SUMMARY.md` - Résumé refactoring V3
- `REFACTORING_V3_1_SUMMARY.md` - Résumé refactoring V3.1

### ⚫ À SUPPRIMER (Obsolète)

Fichiers anciens ou redondants:

- `ADVANCED_ANALYSIS_ARCHITECTURE.md` - Concept ancien
- `ADVANCED_ANALYSIS_GUIDE.md` - Concept ancien
- `ADVANCED_ANALYSIS_QUICK_ACCESS.md` - Concept ancien
- `TELEMETRY_ANALYSIS_INTEGRATION.md` - Redondant avec CHART_INTEGRATION_GUIDE
- `TELEMETRY_SYSTEM_INDEX.md` - Redondant
- `TELEMETRY_INDEX.md` - Redondant
- `TELEMETRY_STORAGE_GUIDE.md` - Redondant avec TELEMETRY_FINAL_REPORT
- `TELEMETRY_STORAGE_VISUAL.md` - Visuel ancien
- `TELEMETRY_INTEGRATION_CHECKLIST.md` - Checklist ancienne
- `TELEMETRY_PERSISTENCE_COMPLETE.md` - Rapport ancien
- `TELEMETRY_GETTING_STARTED.md` - Remplacé par TELEMETRY_QUICK_START
- `INTEGRATION_COMPLETE.md` - Rapport ancien
- `IMPLEMENTATION_CHECKLIST.md` - Checklist ancienne
- `NMEA_ARCHITECTURE.md` - Architecture ancienne
- `NMEA_AUTO_DISCOVERY_COMPLETE.md` - Rapport ancien
- `NMEA_CONFIG_EXAMPLES.md` - Exemples anciens
- `NMEA_INTEGRATION_GUIDE.md` - Guide ancien
- `REGATTA_SOUND_SEQUENCE.md` - Concept ancien
- `SOUNDS_IMPLEMENTATION.md` - Ancien
- `SOUNDS_STATUS.md` - Ancien
- `UI_ARCHITECTURE_V3.md` - Architecture ancienne
- `INDEX.md` - Index ancien
- `WIND_ARCHITECTURE.md` - À vérifier

## 📊 Arborescence Recommandée Après Nettoyage

```
Documentation Essentielle:
├── 00_LIRE_D_ABORD.md
├── QUICK_REFERENCE.md
└── DOCUMENTATION_INDEX.md (ce fichier)

Télémétrie & Sessions (ACTUELLEMENT PERTINENT):
├── TELEMETRY_QUICK_START.md
├── TELEMETRY_FINAL_REPORT.md
├── TELEMETRY_ONE_PAGE.md
├── SESSION_SELECTION_SYSTEM.md
└── TELEMETRY_DIAGNOSTIC_LOGS.md

UI & Graphiques (ACTUELLEMENT PERTINENT):
├── CHART_INTEGRATION_GUIDE.md
├── TELEMETRY_UI_IMPROVEMENTS.md
└── WIND_ARCHITECTURE.md

Son & NMEA (À VÉRIFIER):
├── SOUND_ALARMS_GUIDE.md
└── NMEA_QUICK_START.md

Archive (Historique - À conserver mais séparé):
├── ARCHIVE/
│   ├── Fixes/
│   ├── Changelogs/
│   └── Rapports_Anciens/
```

## ✅ Actions Recommandées

1. **Supprimer** (25 fichiers):
   - Tous les fichiers marqués ⚫ ci-dessus
   
2. **Archiver** (dossier `ARCHIVE/`):
   - Tous les fichiers de fixes et changelogs
   
3. **Vérifier & Mettre à jour**:
   - SOUND_ALARMS_GUIDE.md
   - NMEA_QUICK_START.md
   - WIND_ARCHITECTURE.md

4. **Garder & Maintenir**:
   - Les 8 fichiers marqués ✅ ci-dessus

## 🚀 Commandes de Nettoyage

```bash
# Créer dossier archive
mkdir -p ARCHIVE/Fixes ARCHIVE/Changelogs ARCHIVE/Rapports

# Archiver les fichiers
mv TELEMETRY_COMPLETE_FIX_SUMMARY.md ARCHIVE/Fixes/
mv TELEMETRY_FIX_*.md ARCHIVE/Fixes/
mv FIX_STATEPROVIDER_ERROR.md ARCHIVE/Fixes/
mv CHANGELOG_*.md ARCHIVE/Changelogs/
mv REFACTORING_*.md ARCHIVE/Changelogs/
mv TELEMETRY_ANALYSIS_INTEGRATION.md ARCHIVE/Rapports/
# ... etc

# Supprimer les fichiers obsolètes
rm ADVANCED_ANALYSIS_*.md
rm TELEMETRY_SYSTEM_INDEX.md
rm TELEMETRY_INDEX.md
# ... etc
```

