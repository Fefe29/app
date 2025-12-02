/// Options d'enregistrement de télémétrie
/// Permet de choisir quels types de données enregistrer

class RecordingOptions {
  /// Données de position (latitude, longitude, altitude)
  final bool recordPosition;

  /// Données de vent (direction, force)
  final bool recordWind;

  /// Données de performance (vitesse, cap)
  final bool recordPerformance;

  /// Données de système (température moteur, batterie, etc)
  final bool recordSystem;

  /// Autres données (météo, marées, etc)
  final bool recordOther;

  /// Trace GPS (affichage graphique de la route)
  final bool recordTrace;

  const RecordingOptions({
    this.recordPosition = true,
    this.recordWind = true,
    this.recordPerformance = true,
    this.recordSystem = false,
    this.recordOther = false,
    this.recordTrace = true,
  });

  /// Tout enregistrer
  factory RecordingOptions.all() => const RecordingOptions(
    recordPosition: true,
    recordWind: true,
    recordPerformance: true,
    recordSystem: true,
    recordOther: true,
    recordTrace: true,
  );

  /// Rien enregistrer
  factory RecordingOptions.none() => const RecordingOptions(
    recordPosition: false,
    recordWind: false,
    recordPerformance: false,
    recordSystem: false,
    recordOther: false,
    recordTrace: false,
  );

  /// Profil minimal (position + vent + performance)
  factory RecordingOptions.minimal() => const RecordingOptions(
    recordPosition: true,
    recordWind: true,
    recordPerformance: true,
    recordSystem: false,
    recordOther: false,
    recordTrace: true,
  );

  /// Copier avec modifications
  RecordingOptions copyWith({
    bool? recordPosition,
    bool? recordWind,
    bool? recordPerformance,
    bool? recordSystem,
    bool? recordOther,
    bool? recordTrace,
  }) => RecordingOptions(
    recordPosition: recordPosition ?? this.recordPosition,
    recordWind: recordWind ?? this.recordWind,
    recordPerformance: recordPerformance ?? this.recordPerformance,
    recordSystem: recordSystem ?? this.recordSystem,
    recordOther: recordOther ?? this.recordOther,
    recordTrace: recordTrace ?? this.recordTrace,
  );

  /// Déterminer si une métrique doit être enregistrée
  bool shouldRecord(String metricKey) {
    // Position: nav.* (latitude, longitude, altitude)
    if (metricKey.startsWith('nav.')) {
      return recordPosition;
    }
    
    // Vent: wind.*
    if (metricKey.startsWith('wind.')) {
      return recordWind;
    }
    
    // Performance: perf.*, sog, cog
    if (metricKey.startsWith('perf.') || 
        metricKey == 'nav.sog' || 
        metricKey == 'nav.cog') {
      return recordPerformance;
    }
    
    // Système: engine.*, electrical.*, system.*
    if (metricKey.startsWith('engine.') || 
        metricKey.startsWith('electrical.') || 
        metricKey.startsWith('system.')) {
      return recordSystem;
    }
    
    // Autres
    return recordOther;
  }

  @override
  String toString() => '''RecordingOptions(
    position: $recordPosition,
    wind: $recordWind,
    performance: $recordPerformance,
    system: $recordSystem,
    other: $recordOther
  )''';
}
