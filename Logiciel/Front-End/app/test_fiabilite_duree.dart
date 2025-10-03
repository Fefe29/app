#!/usr/bin/env dart
// Test de la nouvelle logique de fiabilité basée sur la durée

void main() {
  print("🧪 Test de l'indicateur de fiabilité basé sur la durée\n");
  
  testReliabilityLogic();
}

void testReliabilityLogic() {
  print("📊 Test des critères de fiabilité");
  
  // Simulation de différents scenarios
  final scenarios = [
    {
      'name': 'Début collecte (2min sur 20min demandées)',
      'actualDuration': 120,     // 2 minutes
      'requestedDuration': 1200, // 20 minutes  
      'points': 24,
      'expectedReliable': false,
      'expectedPercent': 10.0,
    },
    {
      'name': 'Mi-collecte (10min sur 20min demandées)',
      'actualDuration': 600,     // 10 minutes
      'requestedDuration': 1200, // 20 minutes
      'points': 120,
      'expectedReliable': false, // Pas encore 80%
      'expectedPercent': 50.0,
    },
    {
      'name': 'Presque complet (16min sur 20min demandées)',
      'actualDuration': 960,     // 16 minutes = 80% de 20min
      'requestedDuration': 1200, // 20 minutes
      'points': 192,
      'expectedReliable': false, // < 100% maintenant
      'expectedPercent': 80.0,
    },
    {
      'name': 'Collecte complète (20min sur 20min demandées)',
      'actualDuration': 1200,    // 20 minutes
      'requestedDuration': 1200, // 20 minutes
      'points': 240,
      'expectedReliable': true,
      'expectedPercent': 100.0,
    },
    {
      'name': 'Analyse courte (5min sur 5min demandées)',
      'actualDuration': 300,     // 5 minutes
      'requestedDuration': 300,  // 5 minutes
      'points': 60,
      'expectedReliable': true,  // 100% de la durée demandée
      'expectedPercent': 100.0,
    },
    {
      'name': 'Pas assez de points (5min/5min mais 3 points)',
      'actualDuration': 300,     // 5 minutes = 100% de 5min
      'requestedDuration': 300,  // 5 minutes
      'points': 3,               // < 8 points minimum
      'expectedReliable': false,
      'expectedPercent': 100.0,
    },
  ];
  
  for (final scenario in scenarios) {
    final actualDuration = scenario['actualDuration'] as int;
    final requestedDuration = scenario['requestedDuration'] as int;
    final points = scenario['points'] as int;
    
    // Logique de fiabilité (copie de WindTrendSnapshot)
    final requiredDuration = requestedDuration; // 100% de la durée demandée
    final hasEnoughDuration = actualDuration >= requiredDuration;
    final hasMinimumPoints = points >= 8;
    final isReliable = hasEnoughDuration && hasMinimumPoints;
    
    final completenessPercent = (actualDuration / requestedDuration * 100).clamp(0, 100);
    
    final expectedReliable = scenario['expectedReliable'] as bool;
    final expectedPercent = scenario['expectedPercent'] as double;
    
    final reliableIcon = isReliable ? '🟢' : '🔴';
    final testResult = (isReliable == expectedReliable && 
                       (completenessPercent - expectedPercent).abs() < 0.1) ? '✅' : '❌';
    
    print('$testResult ${scenario['name']}');
    print('   Durée: ${(actualDuration/60).toStringAsFixed(1)}min / ${(requestedDuration/60).toStringAsFixed(0)}min');
    print('   Points: $points');
    print('   Complétude: ${completenessPercent.toStringAsFixed(1)}% (attendu: ${expectedPercent.toStringAsFixed(1)}%)');
    print('   Critères: durée_ok=$hasEnoughDuration, points_ok=$hasMinimumPoints');
    print('   $reliableIcon Fiable: $isReliable (attendu: $expectedReliable)');
    print('');
  }
  
  print("🎯 Logique de fiabilité:");
  print("   ✅ VERT (Fiable): 100% de la durée demandée ET >= 8 points");
  print("   🔴 ROUGE (Insuffisant): < 100% de la durée OU < 8 points");
  print("   📊 Pourcentage affiché: durée_réelle / durée_demandée * 100");
  print("");
  print("💡 Exemples utilisateur:");
  print("   - Demande 20min → Vert après exactement 20min de collecte");
  print("   - Demande 5min → Vert après exactement 5min de collecte");
  print("   - Changement 20min→5min → Immédiatement vert si 5min+ collectées");
  print("   - Changement 5min→20min → Rouge jusqu'à 20min totales collectées");
}