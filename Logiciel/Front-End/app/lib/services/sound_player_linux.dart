import 'dart:io';
import 'package:flutter/services.dart';
import 'sound_player.dart';

class LinuxSoundPlayer implements SoundPlayer {
  bool _muted = false;
  // Use absolute path - safe with Flatpak
  static const String _mpvPath = '/usr/bin/mpv';

  void setMuted(bool muted) => _muted = muted;

  Future<void> _playAsset(String assetPath) async {
    if (_muted) return;
    try {
      print('🔊 [LinuxSoundPlayer] Loading: $assetPath');
      
      // Load asset from Flutter bundle
      final data = await rootBundle.load(assetPath);
      print('🔊 [LinuxSoundPlayer] ✅ Asset loaded: ${data.lengthInBytes} bytes');
      
      // Write to temp file
      final tempDir = Directory.systemTemp;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.wav';
      final tempFile = File('${tempDir.path}/$fileName');
      
      await tempFile.writeAsBytes(data.buffer.asUint8List());
      print('🔊 [LinuxSoundPlayer] ✅ File written to: ${tempFile.path}');
      
      // Verify mpv exists
      final mpvExists = await File(_mpvPath).exists();
      if (!mpvExists) {
        print('❌ [LinuxSoundPlayer] mpv not found at $_mpvPath');
        await tempFile.delete();
        return;
      }
      
      print('🔊 [LinuxSoundPlayer] Playing with mpv...');
      
      // Play with mpv
      final result = await Process.run(
        _mpvPath,
        [
          '--no-video',
          '--no-audio-display',
          '--really-quiet',
          tempFile.path,
        ],
      ).timeout(const Duration(seconds: 10));
      
      print('🔊 [LinuxSoundPlayer] mpv exit code: ${result.exitCode}');
      
      // Clean up
      await Future.delayed(const Duration(milliseconds: 500));
      try {
        await tempFile.delete();
        print('🔊 [LinuxSoundPlayer] ✅ Temp file deleted');
      } catch (e) {
        print('⚠️ [LinuxSoundPlayer] Could not delete: $e');
      }
    } catch (e, st) {
      print('❌ [LinuxSoundPlayer] Error: $e');
    }
  }

  @override
  Future<void> playMedium() async => await _playAsset('assets/sounds/beep_medium.wav');

  @override
  Future<void> playShort() async => await _playAsset('assets/sounds/beep_short.wav');

  @override
  Future<void> playDoubleShort() async => await _playAsset('assets/sounds/beep_double_short.wav');

  @override
  Future<void> playLong() async => await _playAsset('assets/sounds/beep_long.wav');

  @override
  Future<void> playStart() async => await _playAsset('assets/sounds/beep_start.wav');

  @override
  Future<void> playFinish() async => await _playAsset('assets/sounds/beep_finish.wav');

  @override
  Future<void> playSequence(List<({String type, int delayMs})> sequence) async {
    if (_muted) return;
    for (final item in sequence) {
      await Future.delayed(Duration(milliseconds: item.delayMs));
      switch (item.type) {
        case 'short':
          await playShort();
        case 'medium':
          await playMedium();
        case 'double':
          await playDoubleShort();
        case 'long':
          await playLong();
        case 'start':
          await playStart();
        case 'finish':
          await playFinish();
      }
    }
  }
}
