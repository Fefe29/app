import 'package:audioplayers/audioplayers.dart';
import 'sound_player.dart';

class AudioplayersSoundPlayer implements SoundPlayer {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _muted = false;

  AudioplayersSoundPlayer() {
    _audioPlayer.setReleaseMode(ReleaseMode.stop);
  }

  void setMuted(bool muted) => _muted = muted;

  Future<void> _playAsset(String filename) async {
    if (_muted) return;
    try {
      await _audioPlayer.play(AssetSource(filename));
    } catch (e) {
      print('❌ Erreur play: $e');
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
