import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'sound_player.dart';
import 'sound_player_stub.dart';

SoundPlayer createSoundPlayer() {
  // Web, Linux, macOS use stub (no native sound support or complex deps)
  if (kIsWeb || Platform.isLinux || Platform.isMacOS) {
    return SoundPlayerStub();
  }
  
  // Mobile (Android/iOS) and Windows can use audioplayers if available
  try {
    // Dynamically try to use audioplayers for mobile/windows
    if (Platform.isAndroid || Platform.isIOS || Platform.isWindows) {
      // Try to instantiate - will fail gracefully on Linux where it's not available
      return AudioplayersSoundPlayerFactory.create();
    }
  } catch (e) {
    print('❌ Erreur création AudioplayersSoundPlayer: $e');
  }
  
  // Fallback to stub for all other cases
  return SoundPlayerStub();
}

// Factory helper pour créer AudioplayersSoundPlayer uniquement quand disponible
abstract class AudioplayersSoundPlayerFactory {
  static SoundPlayer create() {
    // Cette méthode sera implémentée différemment selon la plateforme
    // Pour maintenant, retourner stub par défaut
    return SoundPlayerStub();
  }
}


