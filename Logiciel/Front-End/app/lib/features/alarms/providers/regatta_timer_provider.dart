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
  final Set<int> _soundPlayedAt = {}; // Tracker les secondes où on a joué des sons

  @override
  RegattaTimerState build() {
    final seq = RegattaSequence.predefined.first;
    return RegattaTimerState(running: false, remaining: seq.total, sequence: seq);
  }

  void selectSequence(RegattaSequence seq) {
    state = RegattaTimerState(running: false, remaining: seq.total, sequence: seq);
    _soundPlayedAt.clear();
  }

  void start() {
    _lastTick = DateTime.now();
    state = state.copyWith(running: true);
    _soundPlayedAt.clear();
    // 🔔 Démarrage: bip extra long
    _sound.playStart();
  }

  void stop() => state = state.copyWith(running: false);

  void reset() {
    state = state.copyWith(remaining: state.sequence.total, running: false);
    _soundPlayedAt.clear();
  }

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
    // ✅ Départ! (0 secondes) - très long bip de finish
    if (oldRemaining > 0 && newRemaining <= 0 && !_soundPlayedAt.contains(0)) {
      _soundPlayedAt.add(0);
      _sound.playFinish();
      return;
    }

    // ✅ Détection des repères dans la séquence
    // Parcourir les repères et jouer le son approprié à chacun
    for (final mark in state.sequence.marks) {
      if (oldRemaining > mark && newRemaining <= mark && !_soundPlayedAt.contains(mark)) {
        _soundPlayedAt.add(mark);
        _handleMarkSound(mark);
        return;
      }
    }

    // ✅ Compte à rebours dans les 10 dernières secondes
    if (newRemaining >= 0 && newRemaining <= 10 && oldRemaining > newRemaining) {
      if (_soundPlayedAt.contains(newRemaining)) return;
      _soundPlayedAt.add(newRemaining);

      // 5 premières secondes (10, 9, 8, 7, 6): double bips rapides
      if (newRemaining >= 6 && newRemaining <= 10) {
        _sound.playDoubleShort();
      }
      // 5 dernières secondes (5, 4, 3, 2, 1): de plus en plus rapide
      else if (newRemaining >= 1 && newRemaining <= 5) {
        final frequency = 6 - newRemaining; // 1→5 reps, 2→4 reps, 3→3 reps, 4→2 reps, 5→1 rep
        _playRepeatedShort(frequency);
      }
      return;
    }
  }

  /// Déterminer le son approprié pour chaque repère
  void _handleMarkSound(int secondsRemaining) {
    // Premier repère (le plus grand) : bip long
    final firstMark = state.sequence.marks.isNotEmpty ? state.sequence.marks.first : 0;
    if (secondsRemaining == firstMark) {
      _sound.playLong();
    } else {
      // Autres repères : bip moyen
      _sound.playMedium();
    }
  }

  /// Jouer rapidement N bips courts en séquence
  Future<void> _playRepeatedShort(int count) async {
    for (int i = 0; i < count; i++) {
      await _sound.playShort();
      if (i < count - 1) {
        await Future.delayed(const Duration(milliseconds: 150));
      }
    }
  }
}

final regattaTimerProvider = NotifierProvider<RegattaTimerNotifier, RegattaTimerState>(RegattaTimerNotifier.new);
