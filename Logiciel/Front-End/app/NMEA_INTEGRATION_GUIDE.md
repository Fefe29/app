# Guide Intégration NMEA 0183 - Miniplexe 2Wi

## 📋 Vue d'ensemble

Votre application Kornog est maintenant capable de se connecter à votre réseau WiFi interne du bateau et de recevoir les données NMEA 0183 du module Miniplexe 2Wi.

## 🔧 Architecture

```
┌─────────────────────────────────────────────────────┐
│         Application Flutter (Kornog)                │
│                                                     │
│  ┌─────────────────────────────────────────────┐   │
│  │        TelemetryBus (Provider Riverpod)     │   │
│  │                                             │   │
│  │  ┌──────────────────────────────────────┐   │   │
│  │  │    FakeTelemetryBus (Simulation)     │   │   │
│  │  │    ou NetworkTelemetryBus (Réel)     │   │   │
│  │  └──────────────────────────────────────┘   │   │
│  └──────────────────┬──────────────────────────┘   │
│                     │                              │
│        ┌────────────┴────────────┐                │
│        │                         │                │
│     Streams de métriques:   Snapshots complets:  │
│     - wind.twd, wind.tws   TelemetrySnapshot    │
│     - nav.sog, nav.cog     (tous metrics)       │
│     - env.depth                                  │
│     - etc.                                       │
└─────────────────────────────────────────────────────┘
         ↑
         │ UDP
         │
    ┌────┴────────┐
    │  Routeur    │
    │  WiFi Bateau│
    └────┬────────┘
         │
         │
    ┌────┴──────────────┐
    │  Miniplexe 2Wi    │
    │  (NMEA 0183)      │
    └───────────────────┘
```

## 📦 Fichiers Créés/Modifiés

### 1. **Dépendances** (`pubspec.yaml`)
```yaml
dependencies:
  udp: ^1.0.0              # Réception UDP
  network_info_plus: ^5.0.0 # Détection réseau
```

### 2. **Parser NMEA** (`lib/common/services/nmea_parser.dart`)
- Classe: `NmeaParser`
- Supporte sentences: RMC, VWT, MWV, DPT, MTW, HDT, VHW, GLL
- Parsing automatique et extraction des métriques

Exemple d'utilisation:
```dart
final result = NmeaParser.parse('\$IIVWT,270.0,T,0.0,M,12.5,N,23.2,K*00');
// result.sentenceType == 'VWT'
// result.measurements['wind.twd'] = 270.0°
// result.measurements['wind.tws'] = 12.5 kt
```

### 3. **Bus Réseau** (`lib/data/datasources/telemetry/network_telemetry_bus.dart`)
- Classe: `NetworkTelemetryBus` implémente `TelemetryBus`
- Classe: `NetworkConfig` pour les paramètres de connexion
- Écoute UDP, parse NMEA, émet métriques

Exemple:
```dart
final config = NetworkConfig(
  host: '192.168.1.100',
  port: 10110,
);
final bus = NetworkTelemetryBus(config: config);
await bus.connect();
```

### 4. **Configuration** (`lib/config/telemetry_config.dart`)
- Enum: `TelemetrySourceMode` (fake vs network)
- Classe: `TelemetryNetworkConfig` (IP, port, enabled)
- Sauvegarde persistée avec `SharedPreferences`

### 5. **Providers** (`lib/common/providers/telemetry_providers.dart`)
- `telemetrySourceModeProvider`: Basculer source
- `telemetryNetworkConfigProvider`: Gérer config réseau
- `networkConnectionProvider`: Tracker état connexion

### 6. **Écran UI** (`lib/features/settings/presentation/screens/network_config_screen.dart`)
- Interface complète de configuration
- Saisie IP/port
- Affichage de l'état de connexion
- Bouton test de connexion

### 7. **Widget Statut** (`lib/features/settings/presentation/widgets/nmea_status_widget.dart`)
- Badge petit pour afficher l'état
- Accès rapide à la config réseau
- Écran paramètres

### 8. **Integration dans `app_providers.dart`**
- `telemetryBusProvider` maintenant sélectionne la source (fake ou network)
- Fallback automatique en cas d'erreur réseau

## 🚀 Utilisation

### Mode Simulation (Par défaut)
L'application utilise `FakeTelemetryBus` pour générer des données localement.

```dart
// Dans lib/config/wind_test_config.dart, vous pouvez configurer:
WindTestConfig.current = WindTestConfig.backingLeft(
  baseDirection: 320.0,
  baseSpeed: 14.0,
  rotationRate: -3.0,
);
```

### Mode Réseau Réel

#### 1️⃣ Configuration du Miniplexe 2Wi
Avant de connecter votre app:

1. **Vérifiez la connexion WiFi du bateau**
   - Connectez-vous au réseau WiFi émis par le Miniplexe
   - Exemple SSID: `Miniplexe-XXXX` (à vérifier)

2. **Trouvez l'IP du Miniplexe**
   - Accédez à l'interface web du routeur (ex: 192.168.1.1)
   - Cherchez l'appareil "Miniplexe" ou "2Wi"
   - Notez son IP (ex: 192.168.1.100)

3. **Vérifiez le port UDP**
   - Port par défaut: **10110** (ou 5013)
   - Consultez la documentation du Miniplexe 2Wi

#### 2️⃣ Configuration dans Kornog

Accédez à l'écran de configuration:

```
Menu Principal → Paramètres → Connexion Télémétrie
```

Ou intégrez le widget dans votre navigation:

```dart
import 'package:kornog/features/settings/presentation/screens/network_config_screen.dart';

// Dans votre router ou navigation:
GoRoute(
  path: '/settings/network',
  builder: (context, state) => const NetworkConfigScreen(),
)
```

**Étapes:**
1. Cliquez sur le bouton **🌐 Réseau** pour activer le mode réseau
2. Saisissez l'IP du Miniplexe (ex: 192.168.1.100)
3. Saisissez le port UDP (ex: 10110)
4. Cliquez sur **Tester la connexion**
5. Vérifiez le statut (vert = connecté ✅)

#### 3️⃣ Widget de statut
Ajoutez ce widget dans votre barre d'app pour afficher l'état:

```dart
import 'package:kornog/features/settings/presentation/widgets/nmea_status_widget.dart';

@override
Widget build(BuildContext context, WidgetRef ref) {
  return MaterialApp.router(
    // ... autres paramètres
    home: Scaffold(
      appBar: AppBar(
        // ... existing app bar content
        actions: [
          const NmeaStatusWidget(),
          const SizedBox(width: 8),
        ],
      ),
      // ...
    ),
  );
}
```

## 📊 Sentences NMEA Supportées

| Sentence | Type | Métriques Extraites |
|----------|------|-------------------|
| **RMC** | Position & Route | `nav.sog`, `nav.cog` |
| **VWT** | Vent Vrai | `wind.twd`, `wind.tws` |
| **MWV** | Angle/Vitesse Vent | `wind.twa`, `wind.awa`, `wind.tws`, `wind.aws` |
| **DPT** | Profondeur | `env.depth` |
| **MTW** | Température Eau | `env.waterTemp` |
| **HDT** | Cap Vrai | `nav.hdg` |
| **VHW** | Vitesse Eau & Cap | `nav.hdg`, `nav.sow` |
| **GLL** | Position GPS | `nav.lat`, `nav.lon` |

## 🔄 Basculer Entre Modes

### Programmatiquement

```dart
// Passer en mode réseau
ref.read(telemetrySourceModeProvider.notifier)
    .setMode(TelemetrySourceMode.network);

// Revenir en simulation
ref.read(telemetrySourceModeProvider.notifier)
    .setMode(TelemetrySourceMode.fake);
```

### Via Configuration

Les paramètres sont sauvegardés persistamment dans `SharedPreferences`:
- `telemetry_source_mode`: 'TelemetrySourceMode.fake' ou '.network'
- `telemetry_network_enabled`: bool
- `telemetry_network_host`: string
- `telemetry_network_port`: int

## 🛠️ Dépannage

### ❌ Connexion échoue

1. **Vérifiez la connexion WiFi**
   - L'app est bien connectée au WiFi du Miniplexe?
   - Testez: `adb shell ping 192.168.1.100`

2. **Vérifiez l'IP et le port**
   - IP correcte? (regardez interface web du routeur)
   - Port correct? (10110 est standard)

3. **Vérifiez le Miniplexe**
   - Est-il allumé?
   - Est-il en mode UDP/NMEA broadcast?
   - Consultez sa documentation

4. **Activer les logs**
   ```dart
   // Les logs UDP apparaissent dans la console:
   // 📡 NMEA: $IIVWT,270.0,T...
   // ✅ Connecté à UDP sur port 10110
   ```

### 📡 Données reçues mais non affichées

1. Vérifiez que les métriques parsées correspondent à vos besoins
2. Vérifiez les clés dans `wind_sample_provider` et autres consumers
3. Ajoutez des print/logs pour debug

### 🔄 Reconnexion automatique

Le système tente une reconnexion toutes les 5 secondes en cas de perte.

## 📈 Intégration dans Votre App

Les données NMEA s'intègrent seamlessly dans votre architecture existante:

```dart
// Tous les consumers existants reçoivent les données NMEA automatiquement!

// Par exemple, votre wind widget:
ref.watch(windSampleProvider) // ← Now reads from NMEA or fake data

// Vos polaires utilisent:
ref.watch(currentWindSpeedProvider) // ← Also automatic!
```

**Aucun changement requis** dans votre logique métier - tout utilise déjà le `TelemetryBus` abstrait!

## 🎯 Prochaines Étapes Optionnelles

1. **Calibration polaire**
   - Enregistrer les données NMEA en conditions réelles
   - Affiner la polaire du J80

2. **Enregistrement historique**
   - Sauvegarder les sessions de navigation
   - Exporter pour analyse post-régate

3. **Multi-talker**
   - Supporter plusieurs sources NMEA (GPS, anémo séparée, etc.)
   - Fusionner les données

4. **Configuration avancée**
   - Filtering de sentences
   - Transformation des données (calibration)
   - Options de logging/enregistrement

## ✅ Checklist Installation

- [ ] Packages UDP/network_info_plus installés (`flutter pub get`)
- [ ] Fichiers créés: nmea_parser.dart, network_telemetry_bus.dart
- [ ] Configuration et providers intégrés
- [ ] Écran UI ajouté à la navigation
- [ ] Widget statut intégré dans AppBar
- [ ] Miniplexe 2Wi connecté et configuré
- [ ] IP/port du Miniplexe identifiés
- [ ] Test de connexion réussi (badge vert)
- [ ] Données NMEA reçues et affichées ✅

---

**Questions?** Consultez les fichiers de documentation du Miniplexe 2Wi ou la norme NMEA 0183.
