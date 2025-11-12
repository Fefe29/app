/// Sleep timer (watch cycle) providers.
/// See ARCHITECTURE_DOCS.md (section: sleep_timer_provider.dart).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/sound_player_factory.dart';
import '../../../services/sound_player.dart';

class SleepTimerState {
  final bool running;
  final DateTime? wakeUpAt;
  final Duration napDuration;
  final bool alarmTriggered; // Alarm a déclenché (pour éviter les re-lectures)
  const SleepTimerState({
    required this.running,
    required this.wakeUpAt,
    required this.napDuration,
    this.alarmTriggered = false,
  });

  SleepTimerState copyWith({
    bool? running,
    DateTime? wakeUpAt,
    Duration? napDuration,
    bool? alarmTriggered,
  }) => SleepTimerState(
        running: running ?? this.running,
        wakeUpAt: wakeUpAt ?? this.wakeUpAt,
        napDuration: napDuration ?? this.napDuration,
        alarmTriggered: alarmTriggered ?? this.alarmTriggered,
      );
}

class SleepTimerNotifier extends Notifier<SleepTimerState> {
  final SoundPlayer _sound = createSoundPlayer();

  @override
  SleepTimerState build() => const SleepTimerState(
    running: false,
    wakeUpAt: null,
    napDuration: Duration(minutes: 20),
  );

  void setDuration(Duration d) => state = state.copyWith(napDuration: d);

  void start() {
    state = state.copyWith(running: true, wakeUpAt: DateTime.now().add(state.napDuration), alarmTriggered: false);
    // Play start sound (medium beep)
    _sound.playMedium();
  }

  void cancel() => state = state.copyWith(running: false, wakeUpAt: null, alarmTriggered: false);

  Duration remaining() {
    if (!state.running || state.wakeUpAt == null) return Duration.zero;
    final diff = state.wakeUpAt!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Appeler régulièrement (chaque seconde) pour vérifier le réveil
  void tick() {
    if (!state.running || state.alarmTriggered) return;
    
    final remaining = this.remaining();
    if (remaining.inSeconds <= 0) {
      // Réveil déclenché!
      _sound.playLong();
      _sound.playLong(); // Double beep long pour un réveil marquant
      state = state.copyWith(running: false, alarmTriggered: true);
    }
  }
}

final sleepTimerProvider = NotifierProvider<SleepTimerNotifier, SleepTimerState>(SleepTimerNotifier.new);
