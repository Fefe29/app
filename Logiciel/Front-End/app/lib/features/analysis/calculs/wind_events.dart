/// Fonctions pour la détection d'événements liés au vent (refus, adonne, oscillation, bascule, front)
import 'dart:math';

/// Détection refus/adonne persistant
/// Compare TWD_lisse_court vs TWD_lisse_long sur une fenêtre
String detectShift(double twdShort, double twdLong, {double seuil = 8.0}) {
  double delta = twdShort - twdLong;
  if (delta > seuil) return 'Adonne';
  if (delta < -seuil) return 'Refus';
  return 'Stable';
}

/// Oscillation: auto-corrélation sur TWD
List<double> autocorrelation(List<double> data) {
  int n = data.length;
  if (n < 2) return [];
  double mean = data.reduce((a, b) => a + b) / n;
  List<double> result = [];
  for (int k = 1; k < n ~/ 2; k++) {
    double sum = 0.0;
    for (int t = k; t < n; t++) {
      sum += (data[t] - mean) * (data[t - k] - mean);
    }
    result.add(sum / (n - k));
  }
  return result;
}

/// CUSUM simple pour détection de bascule
List<double> cusum(List<double> data, double seuil) {
  List<double> pos = [];
  List<double> neg = [];
  double sPos = 0.0, sNeg = 0.0;
  for (var d in data) {
    sPos = max(0, sPos + d);
    sNeg = min(0, sNeg + d);
    pos.add(sPos);
    neg.add(sNeg);
  }
  // Détection dépassement seuil
  // À utiliser dans la logique d'événement
  return [pos.last, neg.last];
}

// Ajoute d'autres fonctions pour front, grain, etc. au besoin...
