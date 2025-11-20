import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'sound_player.dart';
import 'sound_player_stub.dart';
import 'sound_player_audioplayers.dart';

SoundPlayer createSoundPlayer() {
  // Linux, macOS and Web use stub
  if (Platform.isLinux || Platform.isMacOS || kIsWeb) {
    print('🔇 SoundPlayerStub utilisé (plateforme non-supportée)');
    return SoundPlayerStub();
  }
  
  // Android, iOS and Windows use real audio player
  if (Platform.isAndroid || Platform.isIOS || Platform.isWindows) {
    try {
      print('🔊 Création AudioplayersSoundPlayer pour ${Platform.operatingSystem}');
      return AudioplayersSoundPlayer();
    } catch (e) {
      print('❌ Erreur création AudioplayersSoundPlayer: $e');
      return SoundPlayerStub();
    }
  }
  
  print('🔇 SoundPlayerStub utilisé (fallback)');
  return SoundPlayerStub();
}


