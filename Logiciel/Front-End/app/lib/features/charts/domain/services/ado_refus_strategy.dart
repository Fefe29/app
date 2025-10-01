import 'dart:collection';

import '../../providers/wind_simulation_provider.dart';

/// Représente la recommandation d'amure courante.
class TackRecommendation {
  TackRecommendation({
    required this.tackLabel,
    required this.directionMean,
    required this.delta,
    required this.updatedAt,
  });
  final String tackLabel; // 'babord amure' | 'tribord amure'
  final double directionMean; // moyenne fenêtre la plus récente
  final double delta; // diff entre fenêtre récente et précédente
  final DateTime updatedAt;
}

/// Implémente la logique de la classe Python ado_refu_class
/// en se basant sur un flux de WindSample (1 Hz typiquement).
class AdoRefusStrategy {
  AdoRefusStrategy({this.periodSeconds = 5, this.thresholdDeg = 2});

  /// Taille d'une fenêtre en secondes (période). Le code Python original utilise 'periode'.
  final int periodSeconds;
  /// Seuil en degrés au-dessus duquel on change d'amure.
  final double thresholdDeg;

  // Historique circulaire des dernières directions (on garde 2 fenêtres complètes + marge)
  final Queue<_TimedDir> _history = Queue();
  String _currentTack = 'babord amure';
  TackRecommendation? _lastRecommendation;

  TackRecommendation? get last => _lastRecommendation;

  TackRecommendation? ingest(WindSample sample) {
    final now = DateTime.now();
    _history.add(_TimedDir(time: now, dir: sample.directionDeg));

    // On ne garde que les ~2 périodes * 1Hz + marge
    while (_history.length > periodSeconds * 2 + 4) {
      _history.removeFirst();
    }

    if (_history.length < periodSeconds * 2) {
      return _lastRecommendation; // pas encore assez d'échantillons
    }

    // Séparer en deux fenêtres : plus récente et précédente
    final recent = _history.toList().sublist(_history.length - periodSeconds, _history.length);
    final previous = _history.toList().sublist(_history.length - 2 * periodSeconds, _history.length - periodSeconds);

    double meanRecent = _mean(recent.map((e) => e.dir));
    double meanPrevious = _mean(previous.map((e) => e.dir));
    double delta = meanRecent - meanPrevious; // similaire à dir_t_1 - dir_t_0

    String newTack = _currentTack;
    if (delta > thresholdDeg) {
      newTack = 'tribord amure';
    } else if (delta < -thresholdDeg) {
      newTack = 'babord amure';
    }

    if (newTack != _currentTack) {
      _currentTack = newTack;
      _lastRecommendation = TackRecommendation(
        tackLabel: _currentTack,
        directionMean: meanRecent,
        delta: delta,
        updatedAt: now,
      );
      return _lastRecommendation; // changement effectif
    }

    // Mise à jour passive (sans changement d'amure)
    _lastRecommendation = TackRecommendation(
      tackLabel: _currentTack,
      directionMean: meanRecent,
      delta: delta,
      updatedAt: now,
    );
    return _lastRecommendation;
  }

  double _mean(Iterable<double> values) {
    var list = values.toList();
    if (list.isEmpty) return 0;
    return list.reduce((a, b) => a + b) / list.length;
  }
}

class _TimedDir {
  _TimedDir({required this.time, required this.dir});
  final DateTime time;
  final double dir;
}
