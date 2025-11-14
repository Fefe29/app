/// Interface abstraite pour la persistance des données de télémétrie.
/// Cette abstraction permet de changer le format de stockage (JSON, Parquet, SQLite)
/// sans toucher au code métier.
/// 
/// See ARCHITECTURE_DOCS.md (section: Telemetry Storage Layer).

import 'package:kornog/domain/entities/telemetry.dart';

/// Métadonnées d'une session enregistrée
class SessionMetadata {
  const SessionMetadata({
    required this.sessionId,
    required this.startTime,
    required this.endTime,
    required this.snapshotCount,
    required this.sizeBytes,
  });

  /// Identifiant unique de la session (ex: "session_2025_11_14_regatta")
  final String sessionId;

  /// Timestamp du premier snapshot
  final DateTime startTime;

  /// Timestamp du dernier snapshot
  final DateTime endTime;

  /// Nombre total de snapshots enregistrés
  final int snapshotCount;

  /// Taille du fichier en bytes
  final int sizeBytes;

  /// Durée totale de la session
  Duration get duration => endTime.difference(startTime);

  @override
  String toString() => 'SessionMetadata($sessionId: $snapshotCount points, ${(sizeBytes / 1024).toStringAsFixed(1)} KB)';
}

/// Statistiques de performance d'une session
class SessionStats {
  const SessionStats({
    required this.sessionId,
    required this.avgSpeed,
    required this.maxSpeed,
    required this.minSpeed,
    required this.avgWindSpeed,
    required this.maxWindSpeed,
    required this.snapshotCount,
    this.customStats = const {},
  });

  final String sessionId;
  final double avgSpeed;
  final double maxSpeed;
  final double minSpeed;
  final double avgWindSpeed;
  final double maxWindSpeed;
  final int snapshotCount;

  /// Stats personnalisées selon l'implémentation de stockage
  final Map<String, dynamic> customStats;

  @override
  String toString() => 'SessionStats($sessionId: avg=${avgSpeed.toStringAsFixed(1)}kn, max=${maxSpeed.toStringAsFixed(1)}kn)';
}

/// Filtre pour les requêtes de chargement de session
class SessionLoadFilter {
  const SessionLoadFilter({
    this.startTime,
    this.endTime,
    this.metricKeyFilter,
    this.limit,
    this.offset = 0,
  });

  /// Charger les snapshots après ce timestamp (optionnel)
  final DateTime? startTime;

  /// Charger les snapshots avant ce timestamp (optionnel)
  final DateTime? endTime;

  /// Filtre sur les clés de métriques (ex: "wind.*", "nav.sog")
  /// Utilise une pattern glob simple
  final String? metricKeyFilter;

  /// Limiter le nombre de résultats
  final int? limit;

  /// Décalage pour la pagination
  final int offset;

  bool get hasTimeRange => startTime != null || endTime != null;
  bool get hasMetricFilter => metricKeyFilter != null;

  @override
  String toString() =>
      'SessionLoadFilter(time: $startTime-$endTime, metric: $metricKeyFilter, limit: $limit)';
}

/// Interface abstraite pour toute implémentation de stockage de télémétrie.
/// 
/// Contrat :
/// - Les implémentations doivent gérer la persistance des TelemetrySnapshot
/// - Les ID de session doivent être uniques et lisibles
/// - Les opérations doivent être asynchrones et thread-safe
/// - Le format interne peut être JSON, Parquet, SQLite, etc.
abstract class TelemetryStorage {
  /// Sauvegarder une session complète.
  ///
  /// [sessionId]: Identifiant unique de la session (format conseillé: "session_YYYY_MM_DD_name")
  /// [snapshots]: Stream de TelemetrySnapshot à enregistrer
  /// 
  /// Lance une exception si le sessionId existe déjà.
  Future<void> saveSession(
    String sessionId,
    Stream<TelemetrySnapshot> snapshots,
  );

  /// Charger une session complète.
  ///
  /// [sessionId]: Identifiant de la session
  /// 
  /// Lance une exception si la session n'existe pas.
  /// Retourne la liste complète des snapshots.
  Future<List<TelemetrySnapshot>> loadSession(String sessionId);

  /// Charger une session avec filtres optionnels.
  ///
  /// [sessionId]: Identifiant de la session
  /// [filter]: Critères de filtrage (temps, métriques, pagination)
  /// 
  /// Les implémentations devraient supporter au minimum les filtres de temps.
  /// Les filtres de métriques peuvent ne pas être supportés par tous les formats.
  Future<List<TelemetrySnapshot>> loadSessionFiltered(
    String sessionId,
    SessionLoadFilter filter,
  );

  /// Lister toutes les sessions disponibles.
  /// 
  /// Retourne les métadonnées (id, startTime, endTime, taille) sans charger les données.
  Future<List<SessionMetadata>> listSessions();

  /// Obtenir les métadonnées d'une session.
  ///
  /// [sessionId]: Identifiant de la session
  /// 
  /// Lance une exception si la session n'existe pas.
  Future<SessionMetadata> getSessionMetadata(String sessionId);

  /// Obtenir les statistiques de performance d'une session.
  ///
  /// [sessionId]: Identifiant de la session
  /// 
  /// Calcule les stats (moyenne, min, max) sans charger tous les snapshots en mémoire
  /// (optimisé pour les gros fichiers avec Parquet/SQLite).
  Future<SessionStats> getSessionStats(String sessionId);

  /// Supprimer une session et ses données.
  ///
  /// [sessionId]: Identifiant de la session
  /// 
  /// Lance une exception si la session n'existe pas.
  Future<void> deleteSession(String sessionId);

  /// Vérifier si une session existe.
  ///
  /// [sessionId]: Identifiant de la session
  /// 
  /// Retourne true si la session peut être chargée.
  Future<bool> sessionExists(String sessionId);

  /// Exporter une session dans un format standard (CSV, JSON, etc).
  ///
  /// [sessionId]: Identifiant de la session
  /// [format]: Format d'export ("csv", "json", "parquet")
  /// [outputPath]: Chemin de sortie du fichier
  /// 
  /// Lance une exception si le format n'est pas supporté.
  Future<void> exportSession({
    required String sessionId,
    required String format,
    required String outputPath,
  });

  /// Obtenir l'espace disque utilisé par une session.
  ///
  /// [sessionId]: Identifiant de la session
  /// 
  /// Utile pour le monitoring et le nettoyage de disque.
  Future<int> getSessionSizeBytes(String sessionId);

  /// Obtenir l'espace disque total utilisé par toutes les sessions.
  ///
  /// Somme de getSessionSizeBytes() pour toutes les sessions.
  Future<int> getTotalSizeBytes();

  /// Nettoyer les anciennes sessions.
  ///
  /// [olderThan]: Supprimer les sessions plus anciennes que ce nombre de jours
  /// 
  /// Retourne le nombre de sessions supprimées.
  Future<int> cleanupOldSessions({required int olderThanDays});
}
