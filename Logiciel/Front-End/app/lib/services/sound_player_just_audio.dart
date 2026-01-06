import 'package:just_audio/just_audio.dart';
import 'sound_player.dart';
import 'dart:io';

class JustAudioSoundPlayer implements SoundPlayer {
  late AudioPlayer _audioPlayer;
  bool _muted = false;

  JustAudioSoundPlayer() {
    _audioPlayer = AudioPlayer();
    _audioPlayer.playbackEventStream.listen((event) {
      // Handle playback events if needed
    });
  }

  void setMuted(bool muted) => _muted = muted;

  Future<void> _playAsset(String assetPath) async {
    if (_muted) return;
    try {
      print('🔊 [JustAudioSoundPlayer] Tentative play: $assetPath');
      
      // just_audio needs assets:/ prefix for asset loading
      final source = AudioSource.asset(assetPath);
      await _audioPlayer.setAudioSource(source);
      await _audioPlayer.play();
      print('✅ [JustAudioSoundPlayer] Play appelé avec succès');
    } catch (e) {
      print('❌ [JustAudioSoundPlayer] Erreur play $assetPath: $e');
      print('❌ Stack trace: ${StackTrace.current}');
    }
  }

  @override
  Future<void> playMedium() async {
    await _playAsset('assets/sounds/beep_medium.wav');
  }

  @override
  Future<void> playShort() async {
    await _playAsset('assets/sounds/beep_short.wav');
  }

  @override
  Future<void> playDoubleShort() async {
    await _playAsset('assets/sounds/beep_double_short.wav');
  }

  @override
  Future<void> playLong() async {
    await _playAsset('assets/sounds/beep_long.wav');
  }

  @override
  Future<void> playStart() async {
    await _playAsset('assets/sounds/beep_start.wav');
  }

  @override
  Future<void> playFinish() async {
    await _playAsset('assets/sounds/beep_finish.wav');
  }

  @override
  Future<void> playSequence(List<({String type, int delayMs})> sequence) async {
    if (_muted) return;
    for (final item in sequence) {
      await Future.delayed(Duration(milliseconds: item.delayMs));
      switch (item.type) {
        case 'short':
          await playShort();
        case 'medium':
          await playMedium();
        case 'double':
          await playDoubleShort();
        case 'long':
          await playLong();
        case 'start':
          await playStart();
        case 'finish':
          await playFinish();
      }
    }
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}
