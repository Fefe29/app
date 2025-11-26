import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'sound_player.dart';
import 'sound_player_stub.dart';
// import 'sound_player_audioplayers.dart'; // DISABLED - audioplayers requires GStreamer on Linux

SoundPlayer createSoundPlayer() {
  // Linux, macOS and Web use stub
  if (Platform.isLinux || Platform.isMacOS || kIsWeb) {
    print('🔇 SoundPlayerStub utilisé (plateforme non-supportée)');
    return SoundPlayerStub();
  }
  
  // Android, iOS and Windows use stub for now (audioplayers disabled)
  // TODO: Re-enable AudioplayersSoundPlayer when building for Android/iOS only
  /*
  if (Platform.isAndroid || Platform.isIOS || Platform.isWindows) {
    try {
      print('🔊 Création AudioplayersSoundPlayer pour ${Platform.operatingSystem}');
      return AudioplayersSoundPlayer();
    } catch (e) {
      print('❌ Erreur création AudioplayersSoundPlayer: $e');
      return SoundPlayerStub();
    }
  }
  */
  
  print('🔇 SoundPlayerStub utilisé (fallback)');
  return SoundPlayerStub();
}


