import 'package:flutter/foundation.dart' show kIsWeb;
import 'sound_player.dart';
import 'sound_player_stub.dart';

SoundPlayer createSoundPlayer() {
  if (kIsWeb) return SoundPlayerStub();
  // For now always return the stub (no-op) to avoid native plugin linking in desktop/WSL.
  return SoundPlayerStub();
}
