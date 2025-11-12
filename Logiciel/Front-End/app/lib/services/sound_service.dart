/// Sound management service for alarms and notifications.
/// Centralized sound playing with error handling.
import 'package:audioplayers/audioplayers.dart';

/// Type d'alarme sonore
enum SoundType {
  /// Bip simple (profondeur, vent, etc)
  beepShort('assets/sounds/beep_short.wav'),
  /// Bip moyen (alerte standard)
  beepMedium('assets/sounds/beep_medium.wav'),
  /// Double bip court (attention)
  beepDouble('assets/sounds/beep_double_short.wav'),
  /// Bip long (départ, événement majeur)
  beepLong('assets/sounds/beep_long.wav');

  final String path;
  const SoundType(this.path);
}

class SoundService {
  static final SoundService _instance = SoundService._internal();
  late final AudioPlayer _audioPlayer;
  bool _muted = false;

  factory SoundService() {
    return _instance;
  }

  SoundService._internal() {
    _audioPlayer = AudioPlayer();
  }

  /// Jouer un son avec le type spécifié
  Future<void> play(SoundType soundType, {int repeatCount = 1}) async {
    if (_muted) return;

    try {
      for (int i = 0; i < repeatCount; i++) {
        await _audioPlayer.play(
          AssetSource(soundType.path),
          volume: 1.0,
        );
        // Attendre que le son se termine avant de jouer le suivant
        if (repeatCount > 1 && i < repeatCount - 1) {
          await Future.delayed(Duration(milliseconds: 300));
        }
      }
    } catch (e) {
      print('❌ Erreur lors de la lecture du son: $e');
    }
  }

  /// Arrêter la lecture en cours
  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      print('❌ Erreur lors de l\'arrêt du son: $e');
    }
  }

  /// Activer/désactiver le son
  void setMuted(bool muted) {
    _muted = muted;
    if (muted) {
      stop();
    }
  }

  bool get isMuted => _muted;

  /// Sons pour minuteur de régate (compte à rebours)
  Future<void> playRegattaCountdown(int secondsRemaining) async {
    if (_muted) return;
    
    // Séquence de bips différente selon le moment
    if (secondsRemaining == 300) {
      // 5 minutes : un bip
      await play(SoundType.beepShort);
    } else if (secondsRemaining == 240) {
      // 4 minutes : deux bips
      await play(SoundType.beepShort, repeatCount: 2);
    } else if (secondsRemaining == 60) {
      // 1 minute : trois bips
      await play(SoundType.beepShort, repeatCount: 3);
    } else if (secondsRemaining == 0) {
      // Départ! : bip long
      await play(SoundType.beepLong);
    }
  }

  /// Son pour alarme de profondeur
  Future<void> playDepthAlarm() async {
    if (_muted) return;
    await play(SoundType.beepMedium, repeatCount: 2);
  }

  /// Son pour alarme de dérive d'ancre
  Future<void> playAnchorDriftAlarm() async {
    if (_muted) return;
    await play(SoundType.beepDouble, repeatCount: 2);
  }

  /// Son pour alarme de shift du vent
  Future<void> playWindShiftAlarm() async {
    if (_muted) return;
    await play(SoundType.beepMedium, repeatCount: 2);
  }

  /// Son pour alarme de vent faible/fort
  Future<void> playWindThresholdAlarm() async {
    if (_muted) return;
    await play(SoundType.beepMedium);
  }

  /// Son pour réveil (sleep timer)
  Future<void> playSleepAlarm() async {
    if (_muted) return;
    // Séquence plus marquante pour le réveil
    await play(SoundType.beepLong, repeatCount: 2);
  }
}

/// Provider Riverpod pour le service de son
final soundServiceProvider = StateProvider((ref) => SoundService());
