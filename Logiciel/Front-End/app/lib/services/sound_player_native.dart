/// Simplified sound player without external audio library
/// Uses platform channels to play sounds directly
import 'package:flutter/services.dart';
import 'sound_player.dart';

class SoundPlayerNative implements SoundPlayer {
  static const platform = MethodChannel('com.kornog.app/sounds');

  @override
  Future<void> playShort() async {
    try {
      await platform.invokeMethod('playSound', {'sound': 'beep_short'});
    } catch (e) {
      print('❌ Error playShort: $e');
    }
  }

  @override
  Future<void> playMedium() async {
    try {
      await platform.invokeMethod('playSound', {'sound': 'beep_medium'});
    } catch (e) {
      print('❌ Error playMedium: $e');
    }
  }

  @override
  Future<void> playDoubleShort() async {
    try {
      await platform.invokeMethod('playSound', {'sound': 'beep_double_short'});
    } catch (e) {
      print('❌ Error playDoubleShort: $e');
    }
  }

  @override
  Future<void> playLong() async {
    try {
      await platform.invokeMethod('playSound', {'sound': 'beep_long'});
    } catch (e) {
      print('❌ Error playLong: $e');
    }
  }

  @override
  Future<void> playSequence(List<({String type, int delayMs})> sequence) async {
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
      }
    }
  }
}
