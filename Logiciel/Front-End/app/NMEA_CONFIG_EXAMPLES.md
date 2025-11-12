# Configuration NMEA 0183 - Exemples

## Exemple Miniplexe 2Wi (Configuration Typique)

```
# 🌐 Paramètres Réseau du Bateau
NMEA_HOST=192.168.1.100
NMEA_PORT=10110

# Le Miniplexe expose un serveur UDP sur le port 10110
# Sentences disponibles: RMC, VWT, MWV, DPT, MTW, HDT, VHW, GLL
# Format: NMEA 0183 standard avec checksums
# Interval: ~1 seconde (1 Hz)
```

## Valeurs Par Défaut dans l'App

```dart
// lib/config/telemetry_config.dart
const defaultNetworkConfig = TelemetryNetworkConfig(
  enabled: false,  // Commencer en simulation (safe)
  host: '192.168.1.100',  // Remplacer par votre IP
  port: 10110,     // Vérifier le port (10110 est standard)
);
```

## Mode Simulation (Développement)

```dart
// lib/config/wind_test_config.dart
WindTestConfig.current = WindTestConfig.backingLeft(
  baseDirection: 320.0,      // Nord-Ouest
  baseSpeed: 14.0,           // 14 nœuds
  rotationRate: -3.0,        // Bascule gauche 3°/min
  noiseMagnitude: 2.5,       // ±2.5° de bruit réaliste
  oscillationAmplitude: 5.0,
  updateIntervalMs: 1000,    // 1 Hz
);
```

## Exemple Sentences NMEA Reçues

### VWT - True Wind (Vent Vrai)
```
$IIVWT,270.0,T,0.0,M,12.5,N,23.2,K*42
       ↑     ↑       ↑  ↑       ↑
      Dir   T=True  Ignore  Speed Speed
                           (knots) (km/h)
```
→ `wind.twd = 270°`, `wind.tws = 12.5 kt`

### RMC - Position & Route
```
$GPRMC,081350.00,A,4717.113210,N,00833.915187,E,1.295,90.0,050905,,,A*78
                 ↑                                    ↑     ↑
              ACTIVE                                SOG   COG
```
→ `nav.sog = 1.295 kt`, `nav.cog = 90°`

### MWV - Wind Speed & Angle
```
$IIMWV,45.0,T,15.5,N,A*3D
       ↑    ↑ ↑    ↑
    Angle  T Speed Status
   (True)  (knots) (Valid)
```
→ `wind.twa = 45°`, `wind.tws = 15.5 kt`

### DPT - Profondeur
```
$IIDPT,15.3,0.5*3A
       ↑    ↑
    Depth  Offset
   (meters)
```
→ `env.depth = 15.3 m`

### MTW - Température Eau
```
$IIMTW,18.5,C*25
       ↑    ↑
     Temp Unit
    (°C)
```
→ `env.waterTemp = 18.5°C`

## Trouver l'IP du Miniplexe

### Depuis Interface Routeur

```
1. Ouvrir navigateur: http://192.168.1.1 (adapter selon routeur)
2. Connexion (admin/admin ou autre)
3. Chercher "DHCP clients" ou "Connected devices"
4. Chercher "Miniplexe" ou "2Wi"
5. Noter l'IP assignée
```

### Depuis Terminal Linux

```bash
# Scanner le réseau
nmap 192.168.1.0/24 | grep -i miniplexe

# Ou vérifier le WiFi
iwconfig
```

### Depuis Port USB (Backup)

```bash
# Si connexion directe USB du Miniplexe
ls -la /dev/ttyUSB*
# Puis:
minicom -D /dev/ttyUSB0 -b 4800
```

## Changer de Port UDP

Si le port par défaut 10110 ne fonctionne pas:

### Essayer les Ports Courants

| Port | Source | Notes |
|------|--------|-------|
| **10110** | Miniplexe défaut | ← Essayer en premier |
| **5013** | Alternate | Port NMEA standard |
| **9999** | Custom | Peut être configuré |

### Tester Connexion Avant App

```bash
# Linux: Écouter UDP
nc -u -l 192.168.1.xxx 10110

# Ou avec netcat:
socat - UDP-LISTEN:10110

# Depuis le Miniplexe, vérifier que vous recevez des données
# ex: $IIVWT,270.0,T...
```

## Configuration Avancée Miniplexe 2Wi

### Interface Web (Typique)

```
URL: http://192.168.1.100:8080
    ou
    http://192.168.1.100:9000

Chercher:
- Network Settings → NMEA Output
  → UDP Broadcast: ON
  → Port: 10110
  → Sentences: RMC, VWT, MWV, DPT, MTW, HDT
```

### Sentences à Activer

Recommandé pour navigation maximale:
- ✅ RMC (Position, route, vitesse)
- ✅ VWT (Vent vrai)
- ✅ MWV (Angle vent apparent/vrai)
- ✅ DPT (Profondeur)
- ✅ MTW (Température eau)
- ✅ HDT (Cap magnétique)
- ✅ VHW (Vitesse eau, cap)

## Dépannage Rapide

### Teste la Connexion UDP

```bash
# Depuis votre appareil Flutter:
adb shell
ping 192.168.1.100

# Écouter le port:
su
nc -u -l 10110

# Voir les données arriver:
$IIVWT,...
$GPRMC,...
```

### Vérifier Format Miniplexe

```bash
# Les données doivent être:
# Format: $AABBB,d1,d2,...*HH\r\n
# Commencer par $
# Finir par \r\n
# Avoir checksum optional *XX

# Exemple valide:
$IIVWT,270.0,T,0.0,M,12.5,N,23.2,K*42

# Format invalide:
IIVWT,270.0,T,0.0,M,12.5,N,23.2,K  ← Pas de $
$IIVWT 270.0 T 0.0 M 12.5 N 23.2 K    ← Pas de comma
```

## Partage WiFi Depuis PC

Si vous tester sans bateau (dev):

```bash
# Linux: Créer hotspot WiFi
sudo nmtui

# Ou depuis terminal:
nmcli device wifi hotspot ifname wlan0 ssid KornogTest password 12345678

# Python simuler Miniplexe:
python3 -c "
import socket
import time
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
while True:
    msg = b'$IIVWT,270.0,T,0.0,M,12.5,N,23.2,K*42\r\n'
    s.sendto(msg, ('192.168.1.255', 10110))
    time.sleep(1)
"
```

## Monitoring NMEA en Temps Réel

### Via App Kornog

```dart
// Voir les logs dans console:
flutter logs

// Chercher:
// 📡 NMEA: $IIVWT,...
// ✅ Connecté à UDP
// 🔄 Reconnexion...
```

### Via Terminal

```bash
# Monitor UDP sur le port:
tcpdump -i any -n udp port 10110

# Voir les datagram bruts:
tcpdump -i any -n -X udp port 10110
```

---

**Besoin d'aide?** Voir `NMEA_INTEGRATION_GUIDE.md`
