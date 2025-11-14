/// Fonctions de calculs statistiques et basiques pour l'analyse du vent
/// Inclut lissage, stats, gust factor, moyenne directionnelle, etc.
import 'dart:math';

/// Moyenne mobile simple
List<double> movingAverage(List<double> data, int window) {
  if (data.length < window) return [];
  List<double> result = [];
  for (int i = 0; i <= data.length - window; i++) {
    result.add(data.sublist(i, i + window).reduce((a, b) => a + b) / window);
  }
  return result;
}

/// Moyenne mobile exponentielle (EMA)
List<double> exponentialMovingAverage(List<double> data, double alpha) {
  if (data.isEmpty) return [];
  List<double> result = [data.first];
  for (int i = 1; i < data.length; i++) {
    result.add(alpha * data[i] + (1 - alpha) * result.last);
  }
  return result;
}

/// Écart-type sur une fenêtre glissante
double windowStd(List<double> data) {
  if (data.isEmpty) return 0.0;
  double mean = data.reduce((a, b) => a + b) / data.length;
  double sumSq = data.map((x) => pow(x - mean, 2) as double).reduce((a, b) => a + b);
  return sqrt(sumSq / data.length);
}

/// Gust factor : max(AWS) / moy(AWS) sur une fenêtre
double gustFactor(List<double> aws) {
  if (aws.isEmpty) return 0.0;
  double maxAws = aws.reduce(max);
  double meanAws = aws.reduce((a, b) => a + b) / aws.length;
  return maxAws / meanAws;
}

/// Moyenne directionnelle circulaire (évite 359↔1°)
double circularMean(List<double> anglesDeg) {
  if (anglesDeg.isEmpty) return 0.0;
  double x = anglesDeg.map((a) => cos(a * pi / 180)).reduce((a, b) => a + b) / anglesDeg.length;
  double y = anglesDeg.map((a) => sin(a * pi / 180)).reduce((a, b) => a + b) / anglesDeg.length;
  double meanAngle = atan2(y, x) * 180 / pi;
  return (meanAngle + 360) % 360;
}

/// Variance circulaire
double circularVariance(List<double> anglesDeg) {
  if (anglesDeg.isEmpty) return 0.0;
  double x = anglesDeg.map((a) => cos(a * pi / 180)).reduce((a, b) => a + b) / anglesDeg.length;
  double y = anglesDeg.map((a) => sin(a * pi / 180)).reduce((a, b) => a + b) / anglesDeg.length;
  return 1 - sqrt(x * x + y * y);
}

/// Taux de variation (dérivée simple)
List<double> rateOfChange(List<double> data, double dtSeconds) {
  if (data.length < 2) return [];
  List<double> result = [];
  for (int i = 1; i < data.length; i++) {
    result.add((data[i] - data[i - 1]) / dtSeconds);
  }
  return result;
}

// Ajoute d'autres fonctions au besoin...
