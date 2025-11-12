import 'dart:async';
import 'sound_player.dart' as iface;

class SoundPlayerStub implements iface.SoundPlayer {
  @override
  Future<void> playMedium() async {}

  @override
  Future<void> playShort() async {}

  @override
  Future<void> playDoubleShort() async {}

  @override
  Future<void> playLong() async {}

  @override
  Future<void> playSequence(List<({String type, int delayMs})> sequence) async {}
}
