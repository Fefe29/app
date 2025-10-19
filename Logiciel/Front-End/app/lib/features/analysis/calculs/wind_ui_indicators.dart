/// Widgets et helpers pour les indicateurs UI (thermomètre, compas, timeline, etc.)
/// À compléter avec des widgets Flutter selon besoins

// Exemples de helpers pour UI
class WindStabilityIndicator {
  final double stdTwd;
  final double stdTws;
  WindStabilityIndicator(this.stdTwd, this.stdTws);
  String get label => 'Stabilité: σ(TWD)=${stdTwd.toStringAsFixed(1)}, σ(TWS)=${stdTws.toStringAsFixed(1)}';
}

class WindOscillationCompass {
  final double amplitude;
  final double period;
  WindOscillationCompass(this.amplitude, this.period);
  String get label => 'Oscillation: ±${amplitude.toStringAsFixed(1)}°, période ~${period.toStringAsFixed(0)}s';
}

// Ajoute d'autres helpers/widgets pour la timeline, alertes, etc.
