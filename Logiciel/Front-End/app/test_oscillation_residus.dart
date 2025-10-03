#!/usr/bin/env dart
// Test de la nouvelle méthode d'oscillation basée sur les résidus

import 'dart:math' as math;

void main() {
  print("🧪 Test : Oscillation par Résidus de Régression\n");
  
  testRegularTrend();
  print("\n" + "="*60 + "\n");
  testIrregularWind();
}

void testRegularTrend() {
  print("📈 Test 1 : Vent régulier avec tendance constante (-3°/min)");
  
  // Simuler 30 minutes de backing left régulier
  final times = <double>[];
  final angles = <double>[];
  final unwrappedAngles = <double>[];
  
  double currentUnwrapped = 320.0;
  
  for (int i = 0; i <= 180; i++) { // 30 minutes, toutes les 10 secondes
    final timeMin = i / 6.0; // Temps en minutes
    times.add(timeMin);
    
    // Tendance parfaite : -3°/min
    final perfectAngle = 320.0 - 3.0 * timeMin;
    
    // Petit bruit réaliste (±1.5°)
    final noise = (math.Random(42).nextDouble() - 0.5) * 3.0; // Seed fixe pour reproductibilité
    final noisyAngle = perfectAngle + noise;
    
    // Déroulage pour régression
    if (i == 0) {
      unwrappedAngles.add(noisyAngle);
    } else {
      double delta = noisyAngle - (currentUnwrapped % 360);
      while (delta > 180) delta -= 360;
      while (delta < -180) delta += 360;
      currentUnwrapped += delta;
      unwrappedAngles.add(currentUnwrapped);
    }
    
    // Angle original normalisé
    var normalizedAngle = noisyAngle;
    while (normalizedAngle < 0) normalizedAngle += 360;
    while (normalizedAngle >= 360) normalizedAngle -= 360;
    angles.add(normalizedAngle);
  }
  
  // Calcul de la pente
  final slope = linearSlope(times, unwrappedAngles);
  
  // Ancienne méthode : amplitude brute sur angles déroulés
  final minUnwrapped = unwrappedAngles.reduce(math.min);
  final maxUnwrapped = unwrappedAngles.reduce(math.max);
  final oldOscillation = maxUnwrapped - minUnwrapped;
  
  // Nouvelle méthode : résidus de régression
  final newOscillation = oscillationAroundTrend(times, unwrappedAngles, slope);
  
  print("   Durée : 30 minutes (${times.length} échantillons)");
  print("   Pente calculée : ${slope.toStringAsFixed(2)}°/min (théorique : -3.00°/min)");
  print("   Bruit ajouté : ±1.5° (réaliste)");
  print("");
  print("   ❌ Ancienne méthode (amplitude totale) : ${oldOscillation.toStringAsFixed(1)}°");
  print("   ✅ Nouvelle méthode (résidus régression) : ${newOscillation.toStringAsFixed(1)}°");
  print("");
  
  // Test avec seuil de 18°
  const seuil = 18.0;
  print("   Classification (seuil ${seuil}°) :");
  print("   - Ancienne : ${oldOscillation > seuil ? 'IRRÉGULIER ❌' : 'RÉGULIER ✅'}");
  print("   - Nouvelle : ${newOscillation > seuil ? 'IRRÉGULIER ❌' : 'RÉGULIER ✅'}");
}

void testIrregularWind() {
  print("🌪️  Test 2 : Vent vraiment irrégulier (variations chaotiques)");
  
  final times = <double>[];
  final unwrappedAngles = <double>[];
  
  double currentUnwrapped = 320.0;
  final random = math.Random(123);
  
  for (int i = 0; i <= 60; i++) { // 10 minutes
    final timeMin = i / 6.0;
    times.add(timeMin);
    
    // Pas de tendance claire + beaucoup de bruit
    final randomChange = (random.nextDouble() - 0.5) * 20.0; // ±10°
    final chaotic = 320.0 + math.sin(timeMin * 0.5) * 15.0 + randomChange; // Oscillation + bruit
    
    // Déroulage
    if (i == 0) {
      unwrappedAngles.add(chaotic);
    } else {
      double delta = chaotic - (currentUnwrapped % 360);
      while (delta > 180) delta -= 360;
      while (delta < -180) delta += 360;
      currentUnwrapped += delta;
      unwrappedAngles.add(currentUnwrapped);
    }
  }
  
  final slope = linearSlope(times, unwrappedAngles);
  
  final minUnwrapped = unwrappedAngles.reduce(math.min);
  final maxUnwrapped = unwrappedAngles.reduce(math.max);
  final oldOscillation = maxUnwrapped - minUnwrapped;
  
  final newOscillation = oscillationAroundTrend(times, unwrappedAngles, slope);
  
  print("   Durée : 10 minutes (${times.length} échantillons)");
  print("   Pente calculée : ${slope.toStringAsFixed(2)}°/min");
  print("   Nature : Oscillations + bruit important (±10°)");
  print("");
  print("   ❌ Ancienne méthode : ${oldOscillation.toStringAsFixed(1)}°");
  print("   ✅ Nouvelle méthode : ${newOscillation.toStringAsFixed(1)}°");
  print("");
  
  const seuil = 18.0;
  print("   Classification (seuil ${seuil}°) :");
  print("   - Ancienne : ${oldOscillation > seuil ? 'IRRÉGULIER ✅' : 'RÉGULIER ❌'}");
  print("   - Nouvelle : ${newOscillation > seuil ? 'IRRÉGULIER ✅' : 'RÉGULIER ❌'}");
}

double linearSlope(List<double> xs, List<double> ys) {
  final n = xs.length;
  if (n < 2) return 0;
  
  final meanX = xs.reduce((a, b) => a + b) / n;
  final meanY = ys.reduce((a, b) => a + b) / n;
  double num = 0, den = 0;
  for (var i = 0; i < n; i++) {
    final dx = xs[i] - meanX;
    num += dx * (ys[i] - meanY);
    den += dx * dx;
  }
  if (den.abs() < 1e-9) return 0;
  return num / den;
}

double oscillationAroundTrend(List<double> xs, List<double> ys, double slope) {
  if (xs.length != ys.length || xs.length < 2) return 0;
  
  final n = xs.length;
  final meanX = xs.reduce((a, b) => a + b) / n;
  final meanY = ys.reduce((a, b) => a + b) / n;
  
  // Calculer les résidus par rapport à la ligne de régression
  double sumSquaredResiduals = 0;
  for (int i = 0; i < n; i++) {
    final predictedY = meanY + slope * (xs[i] - meanX);
    final residual = ys[i] - predictedY;
    sumSquaredResiduals += residual * residual;
  }
  
  // Écart-type des résidus
  final residualVariance = sumSquaredResiduals / (n - 1);
  final residualStdDev = math.sqrt(residualVariance);
  
  // Convertir en amplitude approximative (±2 écart-types = 95% des données)
  return residualStdDev * 4.0;
}