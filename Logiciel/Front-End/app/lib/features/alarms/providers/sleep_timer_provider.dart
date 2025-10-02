/// Sleep timer (watch cycle) providers.
/// See ARCHITECTURE_DOCS.md (section: sleep_timer_provider.dart).
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SleepTimerState {
  final bool running;
  final DateTime? wakeUpAt;
  final Duration napDuration;
  const SleepTimerState({required this.running, required this.wakeUpAt, required this.napDuration});

  SleepTimerState copyWith({bool? running, DateTime? wakeUpAt, Duration? napDuration}) => SleepTimerState(
        running: running ?? this.running,
        wakeUpAt: wakeUpAt ?? this.wakeUpAt,
        napDuration: napDuration ?? this.napDuration,
      );
}

class SleepTimerNotifier extends Notifier<SleepTimerState> {
  @override
  SleepTimerState build() => const SleepTimerState(running: false, wakeUpAt: null, napDuration: Duration(minutes: 20));

  void setDuration(Duration d) => state = state.copyWith(napDuration: d);

  void start() => state = state.copyWith(running: true, wakeUpAt: DateTime.now().add(state.napDuration));

  void cancel() => state = state.copyWith(running: false, wakeUpAt: null);

  Duration remaining() {
    if (!state.running || state.wakeUpAt == null) return Duration.zero;
    final diff = state.wakeUpAt!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }
}

final sleepTimerProvider = NotifierProvider<SleepTimerNotifier, SleepTimerState>(SleepTimerNotifier.new);
