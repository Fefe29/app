import 'package:audioplayers/audioplayers.dart';
import 'sound_player.dart';

class AudioplayersSoundPlayer implements SoundPlayer {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _muted = false;

  AudioplayersSoundPlayer() {
    _audioPlayer.setReleaseMode(ReleaseMode.stop);
  }

  void setMuted(bool muted) => _muted = muted;

  Future<void> _playAsset(String assetPath) async {
    if (_muted) return;
    try {
      print('🔊 [AudioplayersSoundPlayer] Tentative play: $assetPath');
      
      // Sur Android, les assets sont préfixés avec "assets/"
      // AssetSource les charge automatiquement depuis le bundle
      final source = AssetSource(assetPath);
      print('🔊 [AudioplayersSoundPlayer] Source créée: $source');
      
      await _audioPlayer.play(source);
      print('✅ [AudioplayersSoundPlayer] Play appelé avec succès');
    } catch (e) {
      print('❌ [AudioplayersSoundPlayer] Erreur play $assetPath: $e');
      print('❌ Stack trace: ${StackTrace.current}');
    }
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
  Future<void> playStart() async {
    await _playAsset('sounds/beep_start.wav');
  }

  @override
  Future<void> playFinish() async {
    await _playAsset('sounds/beep_finish.wav');
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
      }
    }
  }
}
