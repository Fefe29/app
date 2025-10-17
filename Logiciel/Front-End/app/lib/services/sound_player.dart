/// Sound player interface. Implementations live in separate files.
abstract class SoundPlayer {
  Future<void> playMedium();
  Future<void> playShort();
  Future<void> playDoubleShort();
  Future<void> playLong();
}
