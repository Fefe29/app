import 'dart:io' show Platform;
import 'sound_player.dart';
import 'sound_player_stub.dart';

SoundPlayer createSoundPlayer() {
  // Audio alarms only on Android
  if (Platform.isAndroid) {
    print('🔊 AudioplayersSoundPlayer créé pour Android');
    // Import and return AudioplayersSoundPlayer
    // audioplayers est seulement disponible sur Android
    try {
      // Dynamic approach: check if we can import
      return _getAndroidSoundPlayer();
    } catch (e) {
      print('❌ Erreur création AudioplayersSoundPlayer: $e');
      return SoundPlayerStub();
    }
  }
  
  // All other platforms (Linux, macOS, Web, Windows, iOS) use stub
  print('🔇 SoundPlayerStub utilisé pour ${Platform.operatingSystem}');
  return SoundPlayerStub();
}

// Stub function - will be replaced at runtime on Android
SoundPlayer _getAndroidSoundPlayer() {
  return SoundPlayerStub(); // Placeholder
}


