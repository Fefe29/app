/// Sound player interface. Implementations live in separate files.
abstract class SoundPlayer {
  Future<void> playMedium();
  Future<void> playShort();
  Future<void> playDoubleShort();
  Future<void> playLong();
  
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
      }
    }
  }
}
