/// Regatta start timer providers.
/// See ARCHITECTURE_DOCS.md (section: regatta_timer_provider.dart).
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Procédure de départ de régate.
class RegattaSequence {
  final String name;
  final List<int> marks; // secondes restantes où un signal est émis
  const RegattaSequence(this.name, this.marks);
  int get total => marks.isNotEmpty ? marks.first : 0;

  static const predefined = <RegattaSequence>[
    RegattaSequence('5-4-1-Go', [300, 240, 60, 0]),
    RegattaSequence('10-5-1-Go', [600, 300, 60, 0]),
    RegattaSequence('3-2-1-Go', [180, 120, 60, 0]),
  ];
}

class RegattaTimerState {
  final bool running;
  final int remaining; // secondes
  final RegattaSequence sequence;
  const RegattaTimerState({required this.running, required this.remaining, required this.sequence});

  RegattaTimerState copyWith({bool? running, int? remaining, RegattaSequence? sequence}) => RegattaTimerState(
        running: running ?? this.running,
        remaining: remaining ?? this.remaining,
        sequence: sequence ?? this.sequence,
      );
}

class RegattaTimerNotifier extends Notifier<RegattaTimerState> {
  DateTime? _lastTick;

  @override
  RegattaTimerState build() {
    final seq = RegattaSequence.predefined.first;
    return RegattaTimerState(running: false, remaining: seq.total, sequence: seq);
  }

  void selectSequence(RegattaSequence seq) {
    state = RegattaTimerState(running: false, remaining: seq.total, sequence: seq);
  }

  void start() {
    _lastTick = DateTime.now();
    state = state.copyWith(running: true);
  }

  void stop() => state = state.copyWith(running: false);

  void reset() => state = state.copyWith(remaining: state.sequence.total, running: false);

  void tick() {
    if (!state.running) return;
    final now = DateTime.now();
    final elapsedSec = now.difference(_lastTick ?? now).inMilliseconds / 1000.0;
    _lastTick = now;
    if (elapsedSec <= 0) return;
    final next = (state.remaining - elapsedSec).floor();
    state = next <= 0 ? state.copyWith(remaining: 0, running: false) : state.copyWith(remaining: next);
  }
}

final regattaTimerProvider = NotifierProvider<RegattaTimerNotifier, RegattaTimerState>(RegattaTimerNotifier.new);
