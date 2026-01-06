import 'dart:io' show Platform;
import 'sound_player.dart';
import 'sound_player_just_audio.dart';
import 'sound_player_linux.dart';

SoundPlayer createSoundPlayer() {
  // Linux: use custom mpv implementation with absolute path (Flatpak safe)
  if (Platform.isLinux) {
    print('🔊 LinuxSoundPlayer créé pour Linux');
    return LinuxSoundPlayer();
  }
  
  // Android, Windows, iOS, macOS: just_audio
  print('🔊 JustAudioSoundPlayer créé pour ${Platform.operatingSystem}');
  return JustAudioSoundPlayer();
}


