#!/usr/bin/env dart
// Test de la correction de l'amplitude d'oscillation sur le long terme

import 'dart:math' as math;

void main() {
  print("🧪 Test : Oscillation sur le Long Terme\n");
  
  // Simulation d'un vent backing left constant (-3°/min) sur 30 minutes
  final angles = <double>[];
  final unwrappedAngles = <double>[];
  
  double currentAngle = 320.0;
  unwrappedAngles.add(currentAngle);
  angles.add(currentAngle);
  
  // Générer 30 minutes de données (toutes les 10 secondes)
  for (int i = 1; i <= 180; i++) { // 30min * 6 échantillons/min
    // Rotation théorique : -3°/min
    final timeMin = i / 6.0; // Temps en minutes
    final theoreticalAngle = 320.0 - 3.0 * timeMin;
    
    // Ajouter du bruit réaliste (±2°)
    final noise = (math.Random().nextDouble() - 0.5) * 4.0;
    var noisyAngle = theoreticalAngle + noise;
    
    // Normaliser dans [0, 360]
    while (noisyAngle < 0) noisyAngle += 360;
    while (noisyAngle >= 360) noisyAngle -= 360;
    
    angles.add(noisyAngle);
    
    // Déroulage pour régression
    final lastUnwrapped = unwrappedAngles.last;
    double delta = noisyAngle - (lastUnwrapped % 360);
    while (delta > 180) delta -= 360;
    while (delta < -180) delta += 360;
    unwrappedAngles.add(lastUnwrapped + delta);
  }
  
  // Test des deux méthodes d'oscillation
  print("📊 Comparaison des méthodes de calcul d'oscillation :");
  print("   Données : ${angles.length} échantillons sur 30 minutes");
  print("   Rotation théorique : -3°/min (${320 - 90}° au total)");
  print("");
  
  // Méthode 1: Amplitude brute sur angles déroulés (FAUSSE)
  final minUnwrapped = unwrappedAngles.reduce(math.min);
  final maxUnwrapped = unwrappedAngles.reduce(math.max);
  final amplitudeDeroulee = maxUnwrapped - minUnwrapped;
  
  print("❌ ANCIENNE méthode (angles déroulés) :");
  print("   Min: ${minUnwrapped.toStringAsFixed(1)}°, Max: ${maxUnwrapped.toStringAsFixed(1)}°");
  print("   Amplitude: ${amplitudeDeroulee.toStringAsFixed(1)}°");
  print("   Problème: L'amplitude augmente avec le temps même pour un vent régulier !");
  
  // Méthode 2: Amplitude brute sur angles originaux (PROBLÉMATIQUE)
  final minOriginal = angles.reduce(math.min);
  final maxOriginal = angles.reduce(math.max);
  final amplitudeOriginale = maxOriginal - minOriginal;
  
  print("\n⚠️  Angles originaux (problématique si transition 0°/360°) :");
  print("   Min: ${minOriginal.toStringAsFixed(1)}°, Max: ${maxOriginal.toStringAsFixed(1)}°");
  print("   Amplitude: ${amplitudeOriginale.toStringAsFixed(1)}°");
  
  // Méthode 3: Écart-type circulaire (CORRECTE)
  final circularMean = calculateCircularMean(angles);
  final standardDev = calculateCircularStandardDeviation(angles, circularMean);
  final amplitudeCorrect = standardDev * 4.0; // ≈ 95% des données
  
  print("\n✅ NOUVELLE méthode (écart-type circulaire) :");
  print("   Moyenne circulaire: ${circularMean.toStringAsFixed(1)}°");
  print("   Écart-type: ${standardDev.toStringAsFixed(1)}°");
  print("   Amplitude équivalente: ${amplitudeCorrect.toStringAsFixed(1)}°");
  print("   Avantage: Stable dans le temps, insensible à la dérive !");
  
  // Test de classification (seuil typique ≈ 18°)
  const double seuil = 18.0;
  print("\n🎯 Classification avec seuil ${seuil}° :");
  print("   Ancienne méthode: ${amplitudeDeroulee > seuil ? 'IRRÉGULIER ❌' : 'RÉGULIER ✅'} (${amplitudeDeroulee.toStringAsFixed(1)}°)");
  print("   Nouvelle méthode: ${amplitudeCorrect > seuil ? 'IRRÉGULIER ❌' : 'RÉGULIER ✅'} (${amplitudeCorrect.toStringAsFixed(1)}°)");
}

double calculateCircularMean(List<double> angles) {
  if (angles.isEmpty) return 0;
  
  double sumSin = 0;
  double sumCos = 0;
  
  for (final angle in angles) {
    final rad = angle * math.pi / 180;
    sumSin += math.sin(rad);
    sumCos += math.cos(rad);
  }
  
  final meanRad = math.atan2(sumSin, sumCos);
  double meanDeg = meanRad * 180 / math.pi;
  if (meanDeg < 0) meanDeg += 360;
  
  return meanDeg;
}

double calculateCircularStandardDeviation(List<double> angles, double mean) {
  if (angles.isEmpty) return 0;
  
  double sumSquaredDeviations = 0;
  
  for (final angle in angles) {
    double deviation = angle - mean;
    while (deviation > 180) deviation -= 360;
    while (deviation < -180) deviation += 360;
    sumSquaredDeviations += deviation * deviation;
  }
  
  final variance = sumSquaredDeviations / angles.length;
  return math.sqrt(variance);
}