// Stub implementation placeholder; actual audioplayers-backed implementation
// removed to avoid bringing native dependencies into desktop builds.
import 'sound_player.dart';

class AudioplayersSoundPlayer implements SoundPlayer {
  @override
  Future<void> playMedium() async {}

  @override
  Future<void> playShort() async {}

  @override
  Future<void> playDoubleShort() async {}

  @override
  Future<void> playLong() async {}
}
