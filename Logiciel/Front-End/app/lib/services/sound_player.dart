/// Sound player interface. Implementations live in separate files.
abstract class SoundPlayer {
  Future<void> playMedium();
  Future<void> playShort();
  Future<void> playDoubleShort();
  Future<void> playLong();
  Future<void> playStart();   // Extra long beep for sequence start
  Future<void> playFinish();  // Very long beep for finish/go
  
  /// Play a sequence of sounds with delays between them
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
        case 'start':
          await playStart();
        case 'finish':
          await playFinish();
      }
    }
  }
}
