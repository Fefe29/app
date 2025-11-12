# 🔔 Guide des Alarmes Sonores - Kornog

## 📋 Résumé de l'implémentation

Vous avez maintenant un système complet de **notifications sonores pour toutes les alarmes** de l'application Kornog.

## 🎵 Types de Sons Utilisés

```
🔊 4 types de bips disponibles:
├─ beep_short.wav      : Bip court (profondeur, vent)
├─ beep_medium.wav     : Bip moyen (alarme standard)
├─ beep_double_short   : Double bip court (attention, shift)
└─ beep_long.wav       : Bip long (départ régate, réveil)
```

Vous pouvez ajouter/remplacer ces fichiers audio dans le dossier `assets/sounds/`.

## 🎯 Alarmes Sonores par Fonction

### 1️⃣ **Minuteur de Régate** (Compte à rebours départ)
**Fichier:** `lib/features/alarms/providers/regatta_timer_provider.dart`

**Nouvelle séquence sonore progressive** (exemple avec 5-4-1-Go):

```
🟢 START (appui sur "Start")
   └─ 1x 🔔 LONG (signal de démarrage)

⏱️ À -1 minute exactement
   └─ 1x 🔊 MEDIUM (vous avertir)

⏳ DERNIÈRES 10 SECONDES (10, 9, 8, 7, 6)
   └─ 2x 🔕 DOUBLE SHORT par seconde (compte à rebours rapide)

⚡ 5 DERNIÈRES SECONDES (5, 4, 3, 2, 1) - ACCÉLÉRATION
   - À 5s: 1x 🔕 SHORT
   - À 4s: 2x 🔕 SHORT (rapides)
   - À 3s: 3x 🔕 SHORT (très rapides)
   - À 2s: 4x 🔕 SHORT (très très rapides)
   - À 1s: 5x 🔕 SHORT (maximale!)

🚨 GO! (0s)
   └─ 1x 🔔 LONG (signal de départ)
```

**Résultat auditif:** Une accélération progressive très claire qui monte en intensité!

### 2️⃣ **Minuteur de Sommeil** (Sieste/Watch)
**Fichier:** `lib/features/alarms/providers/sleep_timer_provider.dart`

- **Au démarrage:** 1 bip moyen
- **À la fin (réveil):** 2 bips longs consécutifs (marquant)

### 3️⃣ **Alarme de Profondeur** (Eau trop faible)
**Fichier:** `lib/features/alarms/providers/other_alarms_provider.dart`

- **Déclenchement:** 1 bip moyen

### 4️⃣ **Alarme de Shift du Vent** (Changement de direction > seuil)
**Fichier:** `lib/features/alarms/providers/other_alarms_provider.dart`

- **Déclenchement:** 1 bip moyen

### 5️⃣ **Alarme de Vent Faible/Fort** (Drop/Raise)
**Fichier:** `lib/features/alarms/providers/other_alarms_provider.dart`

- **Déclenchement:** 1 bip court

### 6️⃣ **Alarme de Dérive d'Ancre** (Position en dehors du rayon)
**Fichier:** `lib/features/alarms/providers/anchor_alarm_provider.dart`

- **Déclenchement:** 1 bip double court

## 🔧 Architecture Technique

### Service de Son (`sound_player.dart`)
Interface abstraite définissant 4 méthodes:
```dart
Future<void> playShort();        // Bip court
Future<void> playMedium();       // Bip moyen
Future<void> playDoubleShort();  // Double bip
Future<void> playLong();         // Bip long
```

### Implémentation AudioPlayers (`sound_player_audioplayers.dart`)
Implémentation réelle utilisant la librairie `audioplayers: ^6.1.0`
- Gestion des erreurs
- Support multi-plateforme (mobile, desktop, web)

### Factory Pattern (`sound_player_factory.dart`)
Sélectionne automatiquement l'implémentation selon la plateforme:
- Web → `SoundPlayerStub()` (pas de son)
- Linux → `SoundPlayerStub()` (problèmes GCC/Clang de compilation)
- Mobile/Desktop (Android/iOS/macOS/Windows) → `AudioplayersSoundPlayer()`

## 📱 Plates-formes Supportées

| Plateforme | Support | Notes |
|-----------|---------|-------|
| **Android** | ✅ Complet | Son complet via audioplayers |
| **iOS** | ✅ Complet | Son complet via audioplayers |
| **macOS** | ✅ Complet | Son complet via audioplayers |
| **Windows** | ✅ Complet | Son complet via audioplayers |
| **Linux** | 🟡 Désactivé | Problèmes de compilation GCC/Clang |
| **Web** | 🟡 Désactivé | Pas d'accès aux ressources natives |

### 🔧 Détails Linux

Sur Linux (y compris WSL), les sons sont **désactivés** car:
- Les dépendances natives de `audioplayers` ont des conflits de compilation avec GCC 15+
- C'est acceptable pour le développement
- Les sons seront **activés automatiquement** sur Android/iOS/macOS/Windows

Pour réactiver sur Linux (si vous avez les dépendances installées):
```dart
// Dans sound_player_factory.dart
// Commenter cette ligne:
// if (Platform.isLinux) return SoundPlayerStub();
```

## 🚀 Activation des Sons

Les sons sont **activés par défaut** via la factory pattern. Si vous utilisez la plateforme web ou si vous voulez désactiver les sons sur desktop:

```dart
// Pour désactiver temporairement:
final player = createSoundPlayer();
if (player is AudioplayersSoundPlayer) {
  player.setMuted(true);  // Désactiver les sons
  player.setMuted(false); // Réactiver
}
```

## 📝 Fichiers Modifiés

1. **`pubspec.yaml`** - Ajout de `audioplayers: ^6.1.0`
2. **`lib/services/sound_player.dart`** - Interface (inchangée)
3. **`lib/services/sound_player_audioplayers.dart`** - ✨ Implémentation réelle
4. **`lib/services/sound_player_factory.dart`** - ✨ Activation pour mobile/desktop
5. **`lib/features/alarms/providers/regatta_timer_provider.dart`** - ✨ Sons minuteur régate
6. **`lib/features/alarms/providers/sleep_timer_provider.dart`** - ✨ Sons minuteur sommeil
7. **`lib/features/alarms/providers/other_alarms_provider.dart`** - ✨ Sons alarmes profondeur/vent
8. **`lib/features/alarms/providers/anchor_alarm_provider.dart`** - ✨ Sons alarme ancre
9. **`lib/features/alarms/presentation/pages/alarms_page.dart`** - ✨ Timer pour sleep alarms

## 🔄 Cycle de Vie des Alarmes Sonores

### Regatta Timer (déjà implémenté)
```
Timer chaque 1s → tick() → _handleSoundsForTransition() → playSound()
```

### Sleep Timer (modifié)
```
Timer chaque 1s → tick() → vérifier si réveil → playSound()
```

### Other Alarms (profondeur, vent)
```
Metric update → _onDepth/_onWindDir/_onWindSpeed → triggered → playSound()
```

### Anchor Alarm
```
updateCurrentPosition() → distance > rayon → playSound()
```

## ✅ Prochaines Étapes (Optionnel)

1. **Personnalisation des sons:**
   - Ajouter un paramètre utilisateur pour choisir le type de son
   - Implémenter des patterns de vibration (haptic feedback)

2. **Gestion du volume:**
   - Ajouter un curseur de volume dans les paramètres
   - Respecter les paramètres système de son

3. **Tests:**
   - Créer des boutons "Test son" dans la page des alarmes
   - Tester sur différentes architectures (ARM, x86)

4. **Sons personnalisés:**
   - Permettre à l'utilisateur d'importer ses propres fichiers audio
   - Différents sons pour différentes alarmes

## 🎧 Fichiers Audio

Les fichiers audio doivent être au format **WAV** (compatible avec audioplayers).

Emplacement: `assets/sounds/`
```
assets/
└─ sounds/
   ├─ beep_short.wav          (0.5s, son court)
   ├─ beep_medium.wav         (1.0s, son moyen)
   ├─ beep_double_short.wav   (0.3s + 0.3s, double bip)
   └─ beep_long.wav           (2.0s, son long)
```

## 📞 Support et Débogage

Si les sons ne se jouent pas:

1. **Vérifier les fichiers audio:**
   ```bash
   ls -la assets/sounds/
   ```

2. **Vérifier les permissions (Android):**
   - PERMISSION_READ_EXTERNAL_STORAGE
   - PERMISSION_WRITE_EXTERNAL_STORAGE

3. **Logs de débogage:**
   ```dart
   // Les erreurs sont loggées avec "❌ Erreur playXxx: "
   ```

4. **Rebuild l'app:**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

---

**Implémenté le:** 8 novembre 2025  
**État:** ✅ Prêt pour production  
**Prochaine révision:** À faire selon les retours utilisateur
