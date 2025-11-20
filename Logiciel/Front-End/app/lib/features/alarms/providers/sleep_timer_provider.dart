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
  final bool alarmActive; // L'alarme sonne activement (true jusqu'à ce que l'user appuie Stop)
  const SleepTimerState({
    required this.running,
    required this.wakeUpAt,
    required this.napDuration,
    this.alarmTriggered = false,
    this.alarmActive = false,
  });

  SleepTimerState copyWith({
    bool? running,
    DateTime? wakeUpAt,
    Duration? napDuration,
    bool? alarmTriggered,
    bool? alarmActive,
  }) => SleepTimerState(
        running: running ?? this.running,
        wakeUpAt: wakeUpAt ?? this.wakeUpAt,
        napDuration: napDuration ?? this.napDuration,
        alarmTriggered: alarmTriggered ?? this.alarmTriggered,
        alarmActive: alarmActive ?? this.alarmActive,
      );
}

class SleepTimerNotifier extends Notifier<SleepTimerState> {
  final SoundPlayer _sound = createSoundPlayer();
  bool _alarmLoopRunning = false;

  @override
  SleepTimerState build() => const SleepTimerState(
    running: false,
    wakeUpAt: null,
    napDuration: Duration(minutes: 20),
  );

  void setDuration(Duration d) => state = state.copyWith(napDuration: d);

  void start() {
    state = state.copyWith(running: true, wakeUpAt: DateTime.now().add(state.napDuration), alarmTriggered: false, alarmActive: false);
    // 🔔 Son de démarrage : bip long
    _sound.playStart();
  }

  void cancel() {
    _alarmLoopRunning = false;
    state = state.copyWith(running: false, wakeUpAt: null, alarmTriggered: false, alarmActive: false);
  }

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
      // 🔔 Réveil déclenché! Son de finish très long
      state = state.copyWith(running: false, alarmTriggered: true, alarmActive: true);
      _startAlarmLoop();
    }
  }

  /// Boucle continue de bips jusqu'à ce que l'utilisateur appuie sur Stop
  void _startAlarmLoop() async {
    if (_alarmLoopRunning) return;
    _alarmLoopRunning = true;

    while (_alarmLoopRunning && state.alarmActive) {
      _sound.playFinish();
      await Future.delayed(const Duration(milliseconds: 500)); // Petit délai entre chaque bip
    }
    
    _alarmLoopRunning = false;
  }

  /// Arrêter l'alarme (appelé quand l'user clique "Stop")
  void stopAlarm() {
    _alarmLoopRunning = false;
    state = state.copyWith(alarmActive: false);
  }
}

final sleepTimerProvider = NotifierProvider<SleepTimerNotifier, SleepTimerState>(SleepTimerNotifier.new);
