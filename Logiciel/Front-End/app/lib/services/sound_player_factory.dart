import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'sound_player.dart';
import 'sound_player_audioplayers.dart';
import 'sound_player_stub.dart';

SoundPlayer createSoundPlayer() {
  // Web and Linux use stub (no native sound support)
  if (kIsWeb || Platform.isLinux) return SoundPlayerStub();
  
  // Mobile, macOS, Windows use audioplayers
  try {
    return AudioplayersSoundPlayer();
  } catch (e) {
    // Fallback to stub if something goes wrong
    return SoundPlayerStub();
  }
}
