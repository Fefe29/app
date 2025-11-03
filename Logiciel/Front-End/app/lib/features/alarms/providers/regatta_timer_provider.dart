/// Regatta start timer providers.
/// See ARCHITECTURE_DOCS.md (section: regatta_timer_provider.dart).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/sound_player_factory.dart';
import '../../../services/sound_player.dart';

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
  final SoundPlayer _sound = createSoundPlayer();

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
    // play medium start sound (e.g. when sequence begins)
    _sound.playMedium();
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
    final newState = next <= 0 ? state.copyWith(remaining: 0, running: false) : state.copyWith(remaining: next);

    // handle sounds for transitions
    _handleSoundsForTransition(oldRemaining: state.remaining, newRemaining: newState.remaining);

    state = newState;
  }

  void _handleSoundsForTransition({required int oldRemaining, required int newRemaining}) {
    // If we crossed an exact sequence mark (e.g., 300,240,60,0), play medium beep
    for (final mark in state.sequence.marks) {
      if (oldRemaining > mark && newRemaining <= mark) {
        // For the 0 mark (Go), play a long beep; other marks get the medium beep
        if (mark == 0) {
          _sound.playLong();
        } else {
          _sound.playMedium();
        }
        return;
      }
    }

    // If we're in the last 10 seconds, play double short beep each second
    if (newRemaining <= 10 && newRemaining >= 0 && newRemaining < oldRemaining) {
      _sound.playDoubleShort();
      return;
    }

    // Minute-level notifications: for marks that are full minutes (multiple of 60), play medium beep when crossing their minute
    final oldMin = (oldRemaining / 60).floor();
    final newMin = (newRemaining / 60).floor();
    if (oldMin != newMin) {
      for (final m in state.sequence.marks) {
        if (m % 60 == 0) {
          final mm = m ~/ 60;
            if (mm == newMin) {
            _sound.playMedium();
            return;
          }
        }
      }
    }
  }
}

final regattaTimerProvider = NotifierProvider<RegattaTimerNotifier, RegattaTimerState>(RegattaTimerNotifier.new);
