import 'dart:io';
import 'package:flutter/services.dart';
import 'sound_player.dart';

class LinuxSoundPlayer implements SoundPlayer {
  bool _muted = false;
  static const String _mpvPath = 'mpv';
  
  /// Cherche mpv dans le PATH
  Future<String?> _findMpvPath() async {
    try {
      final result = await Process.run('which', ['mpv']);
      if (result.exitCode == 0) {
        final path = result.stdout.toString().trim();
        if (path.isNotEmpty) return path;
      }
    } catch (e) {
      // which non disponible, continuer
    }
    
    // Fallback: essayer les chemins courants
    final commonPaths = ['/usr/bin/mpv', '/usr/local/bin/mpv', '/bin/mpv'];
    for (final path in commonPaths) {
      final file = File(path);
      if (await file.exists()) return path;
    }
    
    return null;
  }

  void setMuted(bool muted) => _muted = muted;

  Future<void> _playAsset(String assetPath) async {
    if (_muted) return;
    try {
      print('🔊 [LinuxSoundPlayer] ========== START ==========');
      print('🔊 [LinuxSoundPlayer] Loading: $assetPath');
      
      // Load asset from Flutter bundle
      final data = await rootBundle.load(assetPath);
      print('🔊 [LinuxSoundPlayer] ✅ Asset loaded: ${data.lengthInBytes} bytes');
      
      // Write to temp file
      final tempDir = Directory.systemTemp;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.wav';
      final tempFile = File('${tempDir.path}/$fileName');
      print('🔊 [LinuxSoundPlayer] Temp path: ${tempFile.path}');
      
      await tempFile.writeAsBytes(data.buffer.asUint8List());
      print('🔊 [LinuxSoundPlayer] ✅ File written');
      
      // Verify file exists and has content
      final exists = await tempFile.exists();
      final size = await tempFile.length();
      print('🔊 [LinuxSoundPlayer] File exists: $exists, size: $size bytes');
      
      // Find mpv
      final mpvPath = await _findMpvPath();
      print('🔊 [LinuxSoundPlayer] mpv found at: $mpvPath');
      
      if (!exists || size == 0) {
        print('❌ [LinuxSoundPlayer] Fichier invalid!');
        return;
      }
      
      if (mpvPath == null) {
        print('❌ [LinuxSoundPlayer] mpv non trouvé dans le PATH!');
        return;
      }
      
      print('🔊 [LinuxSoundPlayer] Calling mpv...');
      
      // Play with mpv
      final result = await Process.run(
        mpvPath,
        [
          '--no-video',
          '--no-audio-display',
          '--really-quiet',
          tempFile.path,
        ],
      ).timeout(const Duration(seconds: 10));
      
      print('🔊 [LinuxSoundPlayer] mpv exit code: ${result.exitCode}');
      if (result.stdout.isNotEmpty) print('🔊 [LinuxSoundPlayer] stdout: ${result.stdout}');
      if (result.stderr.isNotEmpty) print('🔊 [LinuxSoundPlayer] stderr: ${result.stderr}');
      
      // Wait before cleanup
      print('🔊 [LinuxSoundPlayer] Waiting 1000ms before cleanup...');
      await Future.delayed(const Duration(milliseconds: 1000));
      
      // Verify file still exists
      final stillExists = await tempFile.exists();
      print('🔊 [LinuxSoundPlayer] File still exists before delete: $stillExists');
      
      // Clean up
      try {
        await tempFile.delete();
        print('🔊 [LinuxSoundPlayer] ✅ Temp file deleted');
      } catch (e) {
        print('⚠️ [LinuxSoundPlayer] Could not delete: $e');
      }
      
      print('🔊 [LinuxSoundPlayer] ========== END ==========');
    } catch (e, st) {
      print('❌ [LinuxSoundPlayer] Erreur: $e');
      print('❌ Stack: $st');
    }
  }

  @override
  Future<void> playMedium() async {
    await _playAsset('assets/sounds/beep_medium.wav');
  }

  @override
  Future<void> playShort() async {
    await _playAsset('assets/sounds/beep_short.wav');
  }

  @override
  Future<void> playDoubleShort() async {
    await _playAsset('assets/sounds/beep_double_short.wav');
  }

  @override
  Future<void> playLong() async {
    await _playAsset('assets/sounds/beep_long.wav');
  }

  @override
  Future<void> playStart() async {
    await _playAsset('assets/sounds/beep_start.wav');
  }

  @override
  Future<void> playFinish() async {
    await _playAsset('assets/sounds/beep_finish.wav');
  }

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
