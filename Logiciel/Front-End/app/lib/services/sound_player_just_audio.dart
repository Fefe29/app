/// Sound player implementation using audioplayers package
import 'package:audioplayers/audioplayers.dart';
import 'sound_player.dart';

class SoundPlayerAudioPlayers implements SoundPlayer {
  late final AudioPlayer _audioPlayer;

  SoundPlayerAudioPlayers() {
    _audioPlayer = AudioPlayer();
  }

  @override
  Future<void> playShort() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/beep_short.wav'));
    } catch (e) {
      print('❌ Error playShort: $e');
    }
  }

  @override
  Future<void> playMedium() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/beep_medium.wav'));
    } catch (e) {
      print('❌ Error playMedium: $e');
    }
  }

  @override
  Future<void> playDoubleShort() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/beep_double_short.wav'));
    } catch (e) {
      print('❌ Error playDoubleShort: $e');
    }
  }

  @override
  Future<void> playLong() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/beep_long.wav'));
    } catch (e) {
      print('❌ Error playLong: $e');
    }
  }

  @override
  Future<void> playSequence(List<({String type, int delayMs})> sequence) async {
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
