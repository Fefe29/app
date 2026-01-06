import 'dart:io' show Platform;
import 'sound_player.dart';
import 'sound_player_just_audio.dart';
import 'sound_player_linux.dart';

SoundPlayer createSoundPlayer() {
  // Linux: custom implementation with full mpv path
  if (Platform.isLinux) {
    print('🔊 LinuxSoundPlayer créé pour Linux');
    return LinuxSoundPlayer();
  }
  
  // Android, Windows, iOS, macOS: just_audio
  if (Platform.isAndroid || Platform.isWindows || Platform.isIOS || Platform.isMacOS) {
    print('🔊 JustAudioSoundPlayer créé pour ${Platform.operatingSystem}');
    return JustAudioSoundPlayer();
  }
  
  // Fallback (shouldn't reach here)
  print('⚠️ Pas d\'implémentation audio pour ${Platform.operatingSystem}');
  return LinuxSoundPlayer();
}


