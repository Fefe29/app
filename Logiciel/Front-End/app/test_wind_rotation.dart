#!/usr/bin/env dart
// Test rapide de la logique de rotation du vent

void main() {
  print("🧪 Test de la correction de rotation du vent\n");
  
  // Configuration backing_left (devrait tourner à GAUCHE)
  const double baseDirection = 320.0;  // Nord-Ouest
  const double rotationRate = -3.0;    // -3°/min vers la gauche
  
  print("📋 Configuration backing_left :");
  print("   Base direction: ${baseDirection}°");
  print("   Rotation rate: ${rotationRate}°/min");
  print("   → Rotation NÉGATIVE = sens anti-horaire = GAUCHE ✓\n");
  
  print("⏱️  Simulation après différents temps :");
  
  for (int minutes = 0; minutes <= 10; minutes += 2) {
    double elapsedMin = minutes.toDouble();
    
    // ANCIENNE logique (FAUSSE) :
    double oldTwd = (baseDirection - rotationRate * elapsedMin) % 360;
    if (oldTwd < 0) oldTwd += 360;
    
    // NOUVELLE logique (CORRECTE) :
    double newTwd = (baseDirection + rotationRate * elapsedMin) % 360;
    if (newTwd < 0) newTwd += 360;
    
    double deltaOld = (oldTwd - baseDirection + 360) % 360;
    if (deltaOld > 180) deltaOld -= 360;
    
    double deltaNew = (newTwd - baseDirection + 360) % 360;
    if (deltaNew > 180) deltaNew -= 360;
    
    print("   Après ${minutes}min :");
    print("     ❌ Ancienne: ${oldTwd.toStringAsFixed(1)}° (Δ=${deltaOld.toStringAsFixed(1)}°)");
    print("     ✅ Nouvelle: ${newTwd.toStringAsFixed(1)}° (Δ=${deltaNew.toStringAsFixed(1)}°)");
    
    if (minutes > 0) {
      String oldDirection = deltaOld > 0 ? "DROITE ❌" : "GAUCHE ✓";
      String newDirection = deltaNew > 0 ? "DROITE ❌" : "GAUCHE ✓";
      print("     → Ancienne logique: $oldDirection");
      print("     → Nouvelle logique: $newDirection");
    }
    print("");
  }
  
  print("🎯 CONCLUSION :");
  print("   - Ancienne logique: backing_left faisait tourner à DROITE ❌");
  print("   - Nouvelle logique: backing_left fait tourner à GAUCHE ✅");
  print("   - Fix: Utiliser directement rotationRate (déjà signé)");
}