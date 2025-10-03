/// 🌊 Configuration du simulateur de vent pour les tests
/// 
/// UTILISATION RAPIDE :
/// 1. Choisissez un preset : WindTestConfig.backingLeft()
/// 2. Personnalisez si besoin : WindTestConfig.backingLeft(rotationRate: 5.0)
/// 3. Redémarrez l'app pour appliquer

class WindTestConfig {
  const WindTestConfig._({
    required String mode,
    required double baseDirection,
    required double baseSpeed,
    required double noiseMagnitude,
    required double rotationRate,
    required double oscillationAmplitude,
    required int updateIntervalMs,
  }) : _mode = mode,
       _baseDirection = baseDirection,
       _baseSpeed = baseSpeed,
       _noiseMagnitude = noiseMagnitude,
       _rotationRate = rotationRate,
       _oscillationAmplitude = oscillationAmplitude,
       _updateIntervalMs = updateIntervalMs;

  final String _mode;
  final double _baseDirection;
  final double _baseSpeed;
  final double _noiseMagnitude;
  final double _rotationRate;
  final double _oscillationAmplitude;
  final int _updateIntervalMs;

  // =========================================================================
  // 🎯 CONFIGURATION ACTIVE (modifiez cette ligne pour changer de preset)
  // =========================================================================
  
  static final WindTestConfig current = WindTestConfig.backingLeft();
  
  // =========================================================================
  // 📋 PRESETS PRÉCONFIGURÉS
  // =========================================================================

  /// 🟢 Vent stable pour débuter ou tester les algorithmes de base
  static WindTestConfig stable({
    double baseDirection = 270.0,    // Ouest
    double baseSpeed = 10.0,
    double noiseMagnitude = 0.5,
    double rotationRate = 0.0,
    double oscillationAmplitude = 1.0,
    int updateIntervalMs = 1000,
  }) => WindTestConfig._(
    mode: 'stable',
    baseDirection: baseDirection,
    baseSpeed: baseSpeed,
    noiseMagnitude: noiseMagnitude,
    rotationRate: rotationRate,
    oscillationAmplitude: oscillationAmplitude,
    updateIntervalMs: updateIntervalMs,
  );

  /// 🟡 Vent irrégulier réaliste (conditions de régate standard)
  static WindTestConfig irregular({
    double baseDirection = 315.0,    // Nord-Ouest
    double baseSpeed = 12.0,
    double noiseMagnitude = 4.0,
    double rotationRate = 0.0,
    double oscillationAmplitude = 10.0,
    int updateIntervalMs = 1000,
  }) => WindTestConfig._(
    mode: 'irregular',
    baseDirection: baseDirection,
    baseSpeed: baseSpeed,
    noiseMagnitude: noiseMagnitude,
    rotationRate: rotationRate,
    oscillationAmplitude: oscillationAmplitude,
    updateIntervalMs: updateIntervalMs,
  );

  /// 🔵 Bascule vers la GAUCHE (favorable au bord de bâbord)
  /// Rotation négative = gauche progressivement
  static WindTestConfig backingLeft({
    double baseDirection = 320.0,    // Nord-Ouest
    double baseSpeed = 14.0,
    double noiseMagnitude = 2.5,
    double rotationRate = -3.0,      // -3°/min vers la gauche
    double oscillationAmplitude = 5.0,
    int updateIntervalMs = 1000,
  }) => WindTestConfig._(
    mode: 'backing_left',
    baseDirection: baseDirection,
    baseSpeed: baseSpeed,
    noiseMagnitude: noiseMagnitude,
    rotationRate: rotationRate,
    oscillationAmplitude: oscillationAmplitude,
    updateIntervalMs: updateIntervalMs,
  );

  /// 🔴 Bascule vers la DROITE (favorable au bord de tribord)
  /// Rotation positive = droite progressivement
  static WindTestConfig veeringRight({
    double baseDirection = 310.0,    // Nord-Ouest
    double baseSpeed = 14.0,
    double noiseMagnitude = 2.5,
    double rotationRate = 3.0,       // +3°/min vers la droite
    double oscillationAmplitude = 5.0,
    int updateIntervalMs = 1000,
  }) => WindTestConfig._(
    mode: 'veering_right',
    baseDirection: baseDirection,
    baseSpeed: baseSpeed,
    noiseMagnitude: noiseMagnitude,
    rotationRate: rotationRate,
    oscillationAmplitude: oscillationAmplitude,
    updateIntervalMs: updateIntervalMs,
  );

  /// ⚡ Vent fort et chaotique (conditions extrêmes)
  static WindTestConfig chaotic({
    double baseDirection = 225.0,    // Sud-Ouest
    double baseSpeed = 18.0,
    double noiseMagnitude = 8.0,
    double rotationRate = 1.5,
    double oscillationAmplitude = 20.0,
    int updateIntervalMs = 800,
  }) => WindTestConfig._(
    mode: 'chaotic',
    baseDirection: baseDirection,
    baseSpeed: baseSpeed,
    noiseMagnitude: noiseMagnitude,
    rotationRate: rotationRate,
    oscillationAmplitude: oscillationAmplitude,
    updateIntervalMs: updateIntervalMs,
  );

  // =========================================================================
  // 🏆 PRESETS TACTIQUES AVANCÉS
  // =========================================================================

  /// 🎯 Bascule tactique RAPIDE vers la gauche (avantage bâbord immédiat)
  static WindTestConfig fastBackingLeft({
    double baseDirection = 340.0,
    double baseSpeed = 16.0,
    double rotationRate = -6.0,      // -6°/min = bascule rapide
    double noiseMagnitude = 1.5,     // Moins de bruit pour analyse précise
    double oscillationAmplitude = 3.0,
    int updateIntervalMs = 1000,
  }) => WindTestConfig._(
    mode: 'backing_left',
    baseDirection: baseDirection,
    baseSpeed: baseSpeed,
    noiseMagnitude: noiseMagnitude,
    rotationRate: rotationRate,
    oscillationAmplitude: oscillationAmplitude,
    updateIntervalMs: updateIntervalMs,
  );

  /// 🎯 Bascule tactique LENTE vers la droite (évolution progressive)
  static WindTestConfig slowVeeringRight({
    double baseDirection = 300.0,
    double baseSpeed = 13.0,
    double rotationRate = 1.5,       // +1.5°/min = bascule lente
    double noiseMagnitude = 3.0,
    double oscillationAmplitude = 7.0,
    int updateIntervalMs = 1000,
  }) => WindTestConfig._(
    mode: 'veering_right',
    baseDirection: baseDirection,
    baseSpeed: baseSpeed,
    noiseMagnitude: noiseMagnitude,
    rotationRate: rotationRate,
    oscillationAmplitude: oscillationAmplitude,
    updateIntervalMs: updateIntervalMs,
  );

  /// 🌪️ Oscillation cyclique (vent qui bascule gauche-droite de façon cyclique)
  static WindTestConfig oscillating({
    double baseDirection = 315.0,
    double baseSpeed = 14.0,
    double noiseMagnitude = 2.0,
    double rotationRate = 0.0,       // Pas de rotation linéaire
    double oscillationAmplitude = 25.0, // Large oscillation
    int updateIntervalMs = 500,      // Mise à jour plus fréquente
  }) => WindTestConfig._(
    mode: 'irregular',
    baseDirection: baseDirection,
    baseSpeed: baseSpeed,
    noiseMagnitude: noiseMagnitude,
    rotationRate: rotationRate,
    oscillationAmplitude: oscillationAmplitude,
    updateIntervalMs: updateIntervalMs,
  );

  // =========================================================================
  // 📊 ACCESSEURS STATIQUES COMPATIBLES (pour FakeTelemetryBus)
  // =========================================================================
  
  static String get mode => current._mode;
  static double get baseDirection => current._baseDirection;
  static double get baseSpeed => current._baseSpeed;
  static double get noiseMagnitude => current._noiseMagnitude;
  static double get rotationRate => current._rotationRate;
  static double get oscillationAmplitude => current._oscillationAmplitude;
  static int get updateIntervalMs => current._updateIntervalMs;
}

// =========================================================================
// 📖 EXEMPLES D'UTILISATION
// =========================================================================
/*

// 🎯 UTILISATION SIMPLE - Preset par défaut
WindTestConfig.current = WindTestConfig.backingLeft();

// 🛠️ PERSONNALISATION - Modifier quelques paramètres
WindTestConfig.current = WindTestConfig.backingLeft(
  rotationRate: -5.0,        // Bascule plus rapide vers la gauche
  baseSpeed: 16.0,           // Vent plus fort
);

// ⚡ BASCULE RAPIDE - Avantage tactique immédiat
WindTestConfig.current = WindTestConfig.fastBackingLeft();

// 🌊 OSCILLATION - Vent qui change de direction cycliquement  
WindTestConfig.current = WindTestConfig.oscillating();

// 🏗️ CONFIGURATION CUSTOM COMPLÈTE
WindTestConfig.current = WindTestConfig.backingLeft(
  baseDirection: 350.0,      // Vent plus au Nord
  rotationRate: -4.5,        // Vitesse de bascule personnalisée
  noiseMagnitude: 1.0,       // Moins de bruit aléatoire
  oscillationAmplitude: 3.0, // Oscillations réduites
  updateIntervalMs: 750,     // Mise à jour plus fréquente
);

*/