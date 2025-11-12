# 🎵 Séquence Sonore Minuteur de Régate

## Résumé Visuel

```
┌─────────────────────────────────────────────────────────────┐
│         SÉQUENCE SONORE PROGRESSIVE DU MINUTEUR             │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  🟢 DÉMARRAGE                                               │
│     └─ 🔔 LONG (2s)                                         │
│                                                              │
│  ⏱️  ATTENTE (4 min 59s → 1 min 1s)                         │
│     └─ [silence - aucun son]                               │
│                                                              │
│  📢 À 1 MINUTE EXACTEMENT                                   │
│     └─ 🔊 MEDIUM (1s) ← Signal d'avertissement             │
│                                                              │
│  ⏳ ATTENTE (59s → 11s)                                     │
│     └─ [silence]                                           │
│                                                              │
│  📊 COMPTE À REBOURS LENT (10s → 6s)                       │
│     ├─ 10s: 🔕🔕 Double SHORT                              │
│     ├─ 9s:  🔕🔕 Double SHORT                              │
│     ├─ 8s:  🔕🔕 Double SHORT                              │
│     ├─ 7s:  🔕🔕 Double SHORT                              │
│     └─ 6s:  🔕🔕 Double SHORT                              │
│                                                              │
│  ⚡ ACCÉLÉRATION DRAMATIQUE (5s → 1s)                      │
│     ├─ 5s: 🔕 (1x)        ← Léger                         │
│     ├─ 4s: 🔕🔕 (2x)      ← Rapide                        │
│     ├─ 3s: 🔕🔕🔕 (3x)    ← Très rapide                   │
│     ├─ 2s: 🔕🔕🔕🔕 (4x)  ← TRÈS TRÈS RAPIDE!           │
│     └─ 1s: 🔕🔕🔕🔕🔕 (5x)← MAXIMALE!!                   │
│                                                              │
│  🚨 DÉPART (0s)                                             │
│     └─ 🔔 LONG (2s) ← GO!                                   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Timing Précis

| Événement | Temps | Son | Nombre |
|-----------|-------|-----|--------|
| Démarrage | START | 🔔 LONG | 1x |
| Minuteur | -1:00 | 🔊 MEDIUM | 1x |
| Compte lent | -0:10 à -0:06 | 🔕 DOUBLE | 1x/sec |
| Accélération | -0:05 | 🔕 SHORT | 1x |
| Accélération | -0:04 | 🔕 SHORT | 2x |
| Accélération | -0:03 | 🔕 SHORT | 3x |
| Accélération | -0:02 | 🔕 SHORT | 4x |
| Accélération | -0:01 | 🔕 SHORT | 5x |
| Départ! | 0:00 | 🔔 LONG | 1x |

## Effet Auditif Total

```
Démarrage        1 minute         10 sec              0 sec
   |               |                |                   |
   ↓               ↓                ↓                   ↓
  [🔔]   silence   [🔊]  silence  [..·..·..·..·..]  accélération!  [🔔]
                                                    •••••
                                                  •••••
                                                •••••
                                              •••••
                                            •••••
                                          [DÉPART]
```

## Implémentation

### Code Principal

```dart
void _handleSoundsForTransition({required int oldRemaining, required int newRemaining}) {
  // 0s → GO!
  if (oldRemaining > 0 && newRemaining <= 0) {
    _sound.playLong();
  }
  // 1 minute exactement
  else if (oldRemaining > 60 && newRemaining <= 60) {
    _sound.playMedium();
  }
  // 10-6 secondes → Double bips
  else if (newRemaining >= 6 && newRemaining <= 10) {
    _sound.playDoubleShort();
  }
  // 5-1 secondes → Accélération
  else if (newRemaining >= 1 && newRemaining <= 5) {
    final frequency = 6 - newRemaining; // 1→5, 2→4, 3→3, 4→2, 5→1
    _playRepeatedShort(frequency);
  }
}
```

### Sous-fonction d'Accélération

```dart
Future<void> _playRepeatedShort(int count) async {
  for (int i = 0; i < count; i++) {
    await _sound.playShort();
    if (i < count - 1) {
      await Future.delayed(const Duration(milliseconds: 150));
    }
  }
}
```

## Type de Sons

| Type | Fichier | Durée | Utilisation |
|------|---------|-------|-------------|
| 🔔 LONG | beep_long.wav | ~2s | Début + Fin |
| 🔊 MEDIUM | beep_medium.wav | ~1s | Minuteur 1min |
| 🔕 DOUBLE | beep_double_short.wav | ~0.6s | Compte lent |
| 🔕 SHORT | beep_short.wav | ~0.5s | Accélération |

## Séquences Prédéfinies

### 5-4-1-Go (300 secondes)
- START → 🔔
- 1:00 → 🔊
- 0:10-0:06 → 🔕🔕 (compte)
- 0:05-0:01 → 🔕 x(1→5)
- 0:00 → 🔔

### 10-5-1-Go (600 secondes)
Même séquence sonore!

### 3-2-1-Go (180 secondes)
Même séquence sonore!

## Avantages de cette Séquence

✅ **Signal clair au démarrage** - Bip long reconnaissable
✅ **Avertissement ponctuel** - Pas de spam, juste à 1 minute
✅ **Progressivité naturelle** - Compte à rebours clair
✅ **Dramatisation finale** - Accélération crescendo très efficace
✅ **Signal final marquant** - GO! impossible à rater
✅ **Professionnel** - Comme une vraie régate!

---

Implémenté le: 8 novembre 2025
