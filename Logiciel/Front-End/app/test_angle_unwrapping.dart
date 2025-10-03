#!/usr/bin/env dart
// Test de l'algorithme de déroulage des angles et convergence vers la vraie pente

import 'dart:math' as math;

void main() {
  print("🧪 Test de l'algorithme de déroulage des angles\n");
  
  // Simulation d'un vent qui tourne de 350° → 10° (backing left)
  testAngleUnwrapping();
  
  print("\n" + "="*60 + "\n");
  
  // Test de convergence avec bruit
  testConvergenceWithNoise();
}

void testAngleUnwrapping() {
  print("📐 Test 1: Déroulage des angles (backing left 350° → 10°)");
  
  // Cas problématique : vent backing left (diminue en traversant 0°)
  // 350° → 340° → 330° → 320° → 310° (rotation normale vers la gauche)
  final List<double> rawAngles = [350.0, 345.0, 340.0, 335.0, 330.0, 325.0, 320.0, 315.0, 310.0];
  
  print("   Angles bruts: ${rawAngles.map((a) => '${a.toStringAsFixed(0)}°').join(', ')}");
  
  final unwrapped = unwrapAngles(rawAngles);
  print("   Déroulés:     ${unwrapped.map((a) => '${a.toStringAsFixed(0)}°').join(', ')}");
  
  // Calcul de pente
  final times = List.generate(rawAngles.length, (i) => i.toDouble()); // 0, 1, 2, ... minutes
  
  final slopeBrute = linearSlope(times, rawAngles);
  final slopeUnwrapped = linearSlope(times, unwrapped);
  
  print("   Pente brute:     ${slopeBrute.toStringAsFixed(2)}°/min");
  print("   Pente déroulée:  ${slopeUnwrapped.toStringAsFixed(2)}°/min");
  print("   Attendu:         -5.0°/min (40° en 8 min)");
  
  print("");
  
  // Test 1b: Cas vraiment problématique avec transition 0°/360°
  print("📐 Test 1b: Transition 0°/360° (backing left)");
  final List<double> crossingAngles = [10.0, 8.0, 5.0, 2.0, 359.0, 356.0, 353.0, 350.0];
  final unwrappedCrossing = unwrapAngles(crossingAngles);
  
  print("   Angles bruts: ${crossingAngles.map((a) => '${a.toStringAsFixed(0)}°').join(', ')}");
  print("   Déroulés:     ${unwrappedCrossing.map((a) => '${a.toStringAsFixed(0)}°').join(', ')}");
  
  final times2 = List.generate(crossingAngles.length, (i) => i.toDouble());
  final slopeCrossingBrute = linearSlope(times2, crossingAngles);
  final slopeCrossingUnwrapped = linearSlope(times2, unwrappedCrossing);
  
  print("   Pente brute:     ${slopeCrossingBrute.toStringAsFixed(2)}°/min (❌ fausse)");
  print("   Pente déroulée:  ${slopeCrossingUnwrapped.toStringAsFixed(2)}°/min (✅ vraie)");
  print("   Attendu:         ~-2.86°/min (20° en 7 min)");
}

void testConvergenceWithNoise() {
  print("📈 Test 2: Convergence vers pente théorique avec bruit");
  
  // Simulation réaliste : backing_left avec -3°/min + bruit
  final theoreticalSlope = -3.0; // °/min
  final baseAngle = 320.0;
  final noiseMagnitude = 2.0;
  
  print("   Pente théorique: ${theoreticalSlope}°/min");
  print("   Bruit simulé: ±${noiseMagnitude}°");
  
  final random = math.Random(42); // seed fixe pour reproductibilité
  
  // Test sur différentes durées
  for (final durationMin in [2, 5, 10, 20, 30]) {
    final times = <double>[];
    final angles = <double>[];
    
    // Générer des points toutes les 10 secondes
    for (double t = 0; t <= durationMin; t += 1/6) { // 1/6 min = 10 secondes
      final theoreticalAngle = baseAngle + theoreticalSlope * t;
      final noise = (random.nextDouble() - 0.5) * 2 * noiseMagnitude;
      var noisyAngle = (theoreticalAngle + noise) % 360;
      if (noisyAngle < 0) noisyAngle += 360;
      
      times.add(t);
      angles.add(noisyAngle);
    }
    
    // Calculer la pente estimée
    final unwrapped = unwrapAngles(angles);
    final estimatedSlope = linearSlope(times, unwrapped);
    final error = (estimatedSlope - theoreticalSlope).abs();
    final errorPercent = (error / theoreticalSlope.abs() * 100);
    
    print("   ${durationMin.toString().padLeft(2)}min (${times.length.toString().padLeft(3)} pts): "
          "${estimatedSlope.toStringAsFixed(2)}°/min "
          "(erreur: ${error.toStringAsFixed(2)}° = ${errorPercent.toStringAsFixed(1)}%)");
  }
  
  print("\n   💡 Plus de données = meilleure précision (bruit moyenné)");
}

List<double> unwrapAngles(List<double> angles) {
  if (angles.length < 2) return List.from(angles);
  
  final result = <double>[angles.first];
  
  for (int i = 1; i < angles.length; i++) {
    double currentAngle = angles[i];
    double previousUnwrapped = result.last;
    
    // Calculer la différence en tenant compte de la circularité
    double delta = currentAngle - (previousUnwrapped % 360);
    
    // Normaliser delta dans [-180, 180]
    while (delta > 180) delta -= 360;
    while (delta < -180) delta += 360;
    
    // Ajouter le delta à l'angle précédent déroulé
    result.add(previousUnwrapped + delta);
  }
  
  return result;
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