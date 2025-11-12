// Note: audioplayers est désactivé pour Linux (dépendances manquantes)
// Ce fichier reste pour compatibilité Android/iOS
// Importe conditionnellement selon la plateforme

import 'sound_player.dart';

// Stub pour Linux (pas d'audioplayers disponible)
class AudioplayersSoundPlayer implements SoundPlayer {
  bool _muted = false;

  AudioplayersSoundPlayer() {
    // Stub - pas d'initialisation
  }

  void setMuted(bool muted) => _muted = muted;

  Future<void> _playAsset(String filename) async {
    if (_muted) return;
    // Stub - pas de son sur cette plateforme
    // ignore: avoid_print
    print('🔇 Son désactivé (plateforme sans support): $filename');
  }

  @override
  Future<void> playMedium() async {
    await _playAsset('sounds/beep_medium.wav');
  }

  @override
  Future<void> playShort() async {
    await _playAsset('sounds/beep_short.wav');
  }

  @override
  Future<void> playDoubleShort() async {
    await _playAsset('sounds/beep_double_short.wav');
  }

  @override
  Future<void> playLong() async {
    await _playAsset('sounds/beep_long.wav');
  }

  @override
  Future<void> playSequence(List<({String type, int delayMs})> sequence) async {
    if (_muted) return;
    for (final item in sequence) {
      await Future.delayed(Duration(milliseconds: item.delayMs));
      // Stub - pas de sons
    }
  }
}
