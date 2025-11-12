# 🚤 KORNOG NMEA 0183 - Quick Reference

## ⚡ TL;DR (Trop Long; Pas Lu)

**TL;DR:** Votre app reçoit maintenant les données NMEA 0183 du Miniplexe via UDP WiFi. 
Basculez simulation ↔ réseau en un clic. Tout se fait automatiquement.

---

## 🚀 Démarrage 3 Minutes

```bash
# 1. Installer packages
flutter pub get

# 2. Compiler
flutter run

# 3. Menu → Paramètres → Connexion Télémétrie
# 4. Basculer: 🌐 Réseau
# 5. IP: 192.168.1.100 (ou votre Miniplexe)
# 6. Port: 10110
# 7. Test → Badge vert ✅
```

**Done!** Données NMEA en live. 🎉

---

## 📊 Ce qui s'est Passé

| Avant | Après |
|-------|-------|
| Données simulées | + Vraies données NMEA ✅ |
| Mode test uniquement | + Mode réseau + Simulation ✅ |
| Architecture fermée | + Flexible (transparence) ✅ |
| Hard-coded data | + Config interface graphique ✅ |

---

## 📁 8 Fichiers Créés

```
lib/
├── common/
│   ├── services/
│   │   └── nmea_parser.dart          (🔍 Parse NMEA)
│   └── providers/
│       └── telemetry_providers.dart  (🔗 Riverpod)
├── config/
│   └── telemetry_config.dart         (⚙️ Config)
├── data/datasources/telemetry/
│   └── network_telemetry_bus.dart    (📡 UDP)
└── features/
    ├── settings/presentation/
    │   ├── screens/
    │   │   └── network_config_screen.dart
    │   └── widgets/
    │       └── nmea_status_widget.dart
    └── telemetry/examples/
        └── nmea_examples.dart

test/
└── nmea_parser_test.dart             (✅ Tests)
```

---

## 🎨 UI/UX Ajouté

### Écran Configuration
```
Settings → Connexion Télémétrie
├── [🎮 Simulation] [🌐 Réseau]  ← Basculer ici
├── IP: 192.168.1.100            ← Entrer ici
├── Port: 10110                  ← Ou ici
├── [Test Connexion]             ← Cliquer
└── Status: ✅ Connecté          ← Voir ici
```

### Widget Statut (Optionnel)
```
AppBar:
  ... existing items ...
  [🌐 NMEA OK] ← Badge vert/rouge
```

---

## 💾 Data Flow

```
Miniplexe 2Wi
    ↓ UDP Port 10110
    ↓ $IIVWT,270.0,T,0.0,M,12.5,N,23.2,K*42
    ↓
NetworkTelemetryBus
    ↓ Parse
NmeaParser
    ↓ Extract
wind.twd = 270°
wind.tws = 12.5 kt
    ↓
Riverpod Streams
    ↓ Auto-update
Your Widgets ✨
```

---

## 🔌 Sentences Reçues

| Sentence | Output |
|----------|--------|
| RMC | `nav.sog`, `nav.cog` |
| VWT | `wind.twd`, `wind.tws` |
| MWV | `wind.twa`, `wind.tws` |
| DPT | `env.depth` |
| MTW | `env.waterTemp` |
| HDT | `nav.hdg` |
| VHW | `nav.hdg`, `nav.sow` |
| GLL | `nav.lat`, `nav.lon` |

---

## 📖 Où Lire?

| Situation | Fichier |
|-----------|---------|
| 😴 Trop fatigué | `NMEA_QUICK_START.md` (5 min) |
| 🏃 Pressé | `NMEA_README.md` (10 min) |
| 🤔 Curieux | `NMEA_INTEGRATION_GUIDE.md` (30 min) |
| 🏗️ Architecture | `NMEA_ARCHITECTURE.md` (diagrammes) |
| 🔧 Config | `NMEA_CONFIG_EXAMPLES.md` |
| ☑️ Checklist | `IMPLEMENTATION_CHECKLIST.md` |
| 💡 Code | `lib/features/telemetry/examples/nmea_examples.dart` |

---

## 🎯 Code Existant - Rien à Changer!

```dart
// ✅ Ceci fonctionne toujours:
ref.watch(windSampleProvider)        // Recoit NMEA auto
ref.watch(metricProvider('wind.tws')) // Recoit NMEA auto
ref.watch(snapshotStreamProvider)    // Recoit NMEA auto

// ✅ Polaires:
polarData.getSpeed(wind, angle)      // Utilise NMEA

// ✅ Routage:
routing.calculateRoute(windData)     // Utilise NMEA

// ✅ Alarmes:
if (depth < minDepth) alarm()        // Utilise NMEA
```

**0% changement requis.** C'est "plug & play"! 🔌

---

## 🆘 Dépannage Express

### ❌ Badge rouge (Déconnecté)

**Check:**
1. WiFi bateau connecté? ✅
2. IP correcte? ✅ (Vérifier routeur)
3. Port UDP correct? ✅ (10110 défaut)
4. Miniplexe actif? ✅

### ❌ Compilation échoue

```bash
flutter clean
flutter pub get
flutter run
```

### ❌ Pas de données

- Miniplexe NMEA output activé?
- UDP broadcast activé?
- Sentences RMC, VWT, etc. activées?

---

## 🔄 Basculer Modes

### Via UI
```
Écran config → [🎮 Simulation] ou [🌐 Réseau]
```

### Via Code
```dart
ref.read(telemetrySourceModeProvider.notifier)
    .setMode(TelemetrySourceMode.network);
```

### Instant!
Sans redémarrage. Données "live" immédiatement.

---

## 📍 Trouver IP Miniplexe

### Rapide
```
Router web (ex: 192.168.1.1)
→ Connected Devices
→ Chercher "Miniplexe" ou "2Wi"
→ Noter IP
```

### Terminal
```bash
nmap 192.168.1.0/24 | grep -i miniplexe
```

---

## ✅ Vérifier Installation

```bash
cd ~/Informatique/Projets/Kornog/app/Logiciel/Front-End/app
bash check_nmea_integration.sh
```

Doit afficher: **🎉 TOUT EST PRÊT!**

---

## 🎁 Bonus: Exemples Usage

### 1. Affichage Simple
```dart
final windSample = ref.watch(windSampleProvider);
Text('${windSample.speed} kt @ ${windSample.directionDeg}°')
```

### 2. Métrique Unique
```dart
final tws = ref.watch(metricProvider('wind.tws'));
tws.when(
  data: (m) => Text('${m.value.toStringAsFixed(1)} kt'),
  loading: () => CircularProgressIndicator(),
  error: (e, _) => Text('Error'),
)
```

### 3. Snapshot Complet
```dart
final snapshot = ref.watch(snapshotStreamProvider);
snapshot.when(
  data: (snap) => ListView(
    children: snap.metrics.entries
        .map((e) => Text('${e.key}: ${e.value.value}'))
        .toList(),
  ),
  // ...
)
```

**Voir: `nmea_examples.dart` pour 4 exemples complets**

---

## 🚢 En Régate

```
Avant départ:
1. WiFi du bateau ✅
2. Miniplexe UDP prêt ✅
3. App config réseau ✅
4. Badge vert ✅

En course:
→ Données réelles NMEA en live! ⛵
→ Polaires calculent avec vraies conditions
→ Alarmes activées automatiquement
→ Analyses affichent vraies tendances
```

---

## 📊 Conversion Unités

NMEA fournit:
- **Angles:** Degrés (0-360°)
- **Vitesse:** Nœuds (knots)
- **Profondeur:** Mètres
- **Température:** Celsius

Tout est déjà converti par `NmeaParser` ✅

---

## 🔐 Status Connexion

```dart
final status = ref.watch(networkConnectionProvider);

status.isConnected       // true/false
status.lastValidData    // DateTime
status.errorMessage     // Erreur si any
```

---

## 🎬 Action Maintenant

```bash
# 1. Get packages
flutter pub get

# 2. Run
flutter run

# 3. Settings → Network Config
# 4. Enter IP/Port
# 5. Test → ✅ Green

# 6. Enjoy! 🚤
```

**Temps total: ~10 min**

---

## 📞 Help

| Problème | Lire |
|----------|------|
| Général | `NMEA_README.md` |
| Rapide | `NMEA_QUICK_START.md` |
| Détails | `NMEA_INTEGRATION_GUIDE.md` |
| Config | `NMEA_CONFIG_EXAMPLES.md` |

---

## ✨ TL;DR Summary

```
✅ Parser NMEA créé (8 sentences)
✅ Bus réseau UDP implémenté
✅ Config UI complète
✅ Riverpod integration
✅ Tests unitaires
✅ Documentation complète
✅ 0 changement code existant
✅ Prêt pour production!
```

**Status: 🚀 READY TO SAIL!**

Connectez le Miniplexe et profitez! ⛵

---

*Quick Reference Card*  
*12 novembre 2025*
