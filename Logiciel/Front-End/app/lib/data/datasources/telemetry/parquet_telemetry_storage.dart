/// Skeleton pour implémentation Parquet de TelemetryStorage.
/// À compléter quand la dépendance Parquet sera intégrée.
/// 
/// Pour l'instant, ce fichier documente l'interface attendue.
/// Utiliser JsonTelemetryStorage en production.

import 'package:kornog/domain/entities/telemetry.dart';
import 'telemetry_storage.dart';

/// Implémentation Parquet - À développer ultérieurement
/// 
/// Avantages vs JSON:
/// - Compression 4-5x meilleure
/// - Requêtes filtrées efficaces
/// - Schéma fort
/// - Support machine learning via pandas/polars
/// 
/// Dépendances à ajouter:
/// ```yaml
/// dependencies:
///   parquet: ^0.2.0  (ou équivalent)
/// ```
class ParquetTelemetryStorage implements TelemetryStorage {
  final String storagePath;

  ParquetTelemetryStorage({required this.storagePath});

  @override
  Future<void> saveSession(
    String sessionId,
    Stream<TelemetrySnapshot> snapshots,
  ) async {
    // TODO: Implémentation Parquet
    // Approche proposée:
    // 1. Accumuler les snapshots dans une table Arrow
    // 2. Écrire en format Parquet avec compression Snappy
    // 3. Sauvegarder les métadonnées en JSON
    throw UnimplementedError('ParquetTelemetryStorage not yet implemented');
  }

  @override
  Future<List<TelemetrySnapshot>> loadSession(String sessionId) async {
    // TODO: Charger Parquet et convertir en snapshots
    throw UnimplementedError('ParquetTelemetryStorage not yet implemented');
  }

  @override
  Future<List<TelemetrySnapshot>> loadSessionFiltered(
    String sessionId,
    SessionLoadFilter filter,
  ) async {
    // TODO: Utiliser les capacités de filtrage Parquet
    // - Pushdown des prédicats (time range)
    // - Projection des colonnes (metric filter)
    // Beaucoup plus efficace que JSON!
    throw UnimplementedError('ParquetTelemetryStorage not yet implemented');
  }

  @override
  Future<List<SessionMetadata>> listSessions() async {
    // TODO: Implémenter
    throw UnimplementedError('ParquetTelemetryStorage not yet implemented');
  }

  @override
  Future<SessionMetadata> getSessionMetadata(String sessionId) async {
    // TODO: Implémenter
    throw UnimplementedError('ParquetTelemetryStorage not yet implemented');
  }

  @override
  Future<SessionStats> getSessionStats(String sessionId) async {
    // TODO: Parquet peut calculer min/max/avg sans charger toutes les données!
    // Beaucoup plus efficace
    throw UnimplementedError('ParquetTelemetryStorage not yet implemented');
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    // TODO: Implémenter
    throw UnimplementedError('ParquetTelemetryStorage not yet implemented');
  }

  @override
  Future<bool> sessionExists(String sessionId) async {
    // TODO: Implémenter
    throw UnimplementedError('ParquetTelemetryStorage not yet implemented');
  }

  @override
  Future<void> exportSession({
    required String sessionId,
    required String format,
    required String outputPath,
  }) async {
    // TODO: Implémenter
    // Formats supportés: 'csv', 'json', 'jsonl', 'parquet'
    throw UnimplementedError('ParquetTelemetryStorage not yet implemented');
  }

  @override
  Future<int> getSessionSizeBytes(String sessionId) async {
    // TODO: Implémenter
    throw UnimplementedError('ParquetTelemetryStorage not yet implemented');
  }

  @override
  Future<int> getTotalSizeBytes() async {
    // TODO: Implémenter
    throw UnimplementedError('ParquetTelemetryStorage not yet implemented');
  }

  @override
  Future<int> cleanupOldSessions({required int olderThanDays}) async {
    // TODO: Implémenter
    throw UnimplementedError('ParquetTelemetryStorage not yet implemented');
  }
}

// ============================================================================
// Helpers pour migration JSON -> Parquet
// ============================================================================

/// Utility pour convertir les données JSON en Parquet
/// À utiliser comme fonction CLI ou service de migration
class ParquetMigrationHelper {
  /// Convertir un fichier JSON Lines (compressé) en Parquet
  /// 
  /// Exemple usage:
  /// ```dart
  /// await ParquetMigrationHelper.convertJsonToParquet(
  ///   jsonLinesFile: 'session.jsonl.gz',
  ///   outputFile: 'session.parquet',
  /// );
  /// ```
  static Future<void> convertJsonToParquet({
    required String jsonLinesFile,
    required String outputFile,
  }) async {
    // TODO: Implémenter conversion
    // 1. Lire JSON Lines (décompresser)
    // 2. Parser les snapshots
    // 3. Construire table Arrow
    // 4. Écrire Parquet
    throw UnimplementedError('Parquet migration not yet implemented');
  }

  /// Batch convert: toutes les sessions JSON -> Parquet
  static Future<int> migrateAllSessions({
    required String inputDirectory,
    required String outputDirectory,
  }) async {
    // TODO: Implémenter
    // 1. Scanner inputDirectory pour .jsonl.gz
    // 2. Convertir chacun
    // 3. Retourner le nombre converti
    throw UnimplementedError('Parquet migration not yet implemented');
  }
}
