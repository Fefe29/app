/// Implémentation du stockage télémétrie avec JSON Lines compressé en GZIP.
/// Format idéal pour le développement et les petits volumes de données.
/// 
/// Format de fichier :
/// - Extension : .jsonl.gz
/// - Contenu : Chaque ligne = 1 snapshot JSON compressé
/// - Exemple ligne :
///   {"ts":"2025-11-14T10:30:00.000Z","metrics":{"nav.sog":6.4,"wind.twd":280.5}}
/// 
/// Avantages :
/// - Lisible et debuggable
/// - Pas de dépendance externe
/// - Compression ~70% de l'espace
/// 
/// Inconvénients :
/// - Requêtes lentes (charge tout)
/// - Filtrage en mémoire
/// - Pas de schéma fort

import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:kornog/domain/entities/telemetry.dart';
import 'telemetry_storage.dart';

class JsonTelemetryStorage implements TelemetryStorage {
  /// Répertoire racine pour stocker les sessions
  final Directory storageDir;

  /// Buffer size pour l'écriture/lecture (défaut: 256KB)
  final int bufferSize;

  JsonTelemetryStorage({
    required this.storageDir,
    this.bufferSize = 256 * 1024,
  });

  /// Répertoire des sessions
  Directory get _sessionsDir {
    final dir = Directory(path.join(storageDir.path, 'sessions'));
    return dir;
  }

  /// Répertoire des métadonnées
  Directory get _metadataDir {
    final dir = Directory(path.join(storageDir.path, 'metadata'));
    return dir;
  }

  /// Chemin du fichier pour une session
  String _sessionFilePath(String sessionId) =>
      path.join(_sessionsDir.path, '$sessionId.jsonl.gz');

  /// Chemin du fichier métadonnées pour une session
  String _metadataFilePath(String sessionId) =>
      path.join(_metadataDir.path, '$sessionId.json');

  /// Initialiser les répertoires
  Future<void> _ensureDirectories() async {
    await _sessionsDir.create(recursive: true);
    await _metadataDir.create(recursive: true);
  }

  @override
  Future<void> saveSession(
    String sessionId,
    Stream<TelemetrySnapshot> snapshots,
  ) async {
    print('📝 [TelemetryStorage] Démarrage saveSession: $sessionId');
    
    await _ensureDirectories();

    final sessionFile = File(_sessionFilePath(sessionId));
    if (await sessionFile.exists()) {
      print('❌ [TelemetryStorage] Session $sessionId existe déjà');
      throw Exception('Session $sessionId already exists');
    }

    print('📂 [TelemetryStorage] Chemin fichier: ${sessionFile.path}');

    // CHANGEMENT: Écriture immédiate ligne par ligne plutôt que buffering
    // Cela permet à getCurrentStats() de voir les données pendant l'enregistrement
    DateTime? firstSnapshot;
    DateTime? lastSnapshot;
    int snapshotCount = 0;
    final linesBuffer = <String>[]; // Buffer temporaire avant compression
    int lastFlushTime = DateTime.now().millisecondsSinceEpoch;
    
    // Créer un IOSink pour écrire directement
    final output = sessionFile.openWrite();

    try {
      print('🔄 [TelemetryStorage] Attente de snapshots du stream...');
      await for (final snapshot in snapshots) {
        print('📥 [TelemetryStorage] Snapshot #${snapshotCount + 1} reçu: ${snapshot.ts}');
        
        // Mémoriser les timestamps
        firstSnapshot ??= snapshot.ts;
        lastSnapshot = snapshot.ts;

        // Convertir en JSON
        final jsonLine = _snapshotToJsonLine(snapshot);
        linesBuffer.add(jsonLine);
        snapshotCount++;

        // CHANGEMENT: Flush immédiat tous les 10 snapshots (au lieu de 100)
        // Cela permet aux lectures concurrentes de voir les données plus rapidement
        if (snapshotCount % 10 == 0) {
          print('💾 [TelemetryStorage] Flush immédiat #$snapshotCount: ${linesBuffer.length} lignes');
          final line = '${linesBuffer.join('\n')}\n';
          final encoded = utf8.encode(line);
          final compressed = GZipCodec().encode(encoded);
          print('   → ${encoded.length} bytes → ${compressed.length} bytes compressés');
          output.add(compressed);
          
          // Flush le sink pour forcer l'écriture disque
          print('   → Flush du IOSink...');
          await output.flush();
          print('   ✅ Données écrites sur le disque');
          
          linesBuffer.clear();
          lastFlushTime = DateTime.now().millisecondsSinceEpoch;
        }

        if (snapshotCount % 50 == 0) {
          print('📊 [TelemetryStorage] Total: $snapshotCount snapshots enregistrés');
        }
      }

      print('✅ [TelemetryStorage] Fin du stream (fermeture détectée après $snapshotCount snapshots)');
      
      // Flusher le reste
      if (linesBuffer.isNotEmpty) {
        print('💾 [TelemetryStorage] Flush FINAL: ${linesBuffer.length} snapshots restants');
        final line = '${linesBuffer.join('\n')}\n';
        final encoded = utf8.encode(line);
        final compressed = GZipCodec().encode(encoded);
        print('   → ${encoded.length} bytes → ${compressed.length} bytes compressés');
        output.add(compressed);
        
        print('   → Flush final du IOSink...');
        await output.flush();
        print('   ✅ Données finales écrites sur le disque');
      }

      print('🔒 [TelemetryStorage] Fermeture du sink...');
      await output.close();
      print('✅ [TelemetryStorage] IOSink fermé avec succès');
    } catch (e, st) {
      // Nettoyer en cas d'erreur
      print('❌ [TelemetryStorage] Erreur écriture: $e');
      print('   StackTrace: $st');
      try {
        await output.close();
      } catch (_) {}
      if (await sessionFile.exists()) {
        await sessionFile.delete();
        print('🗑️ [TelemetryStorage] Fichier supprimé (cleanup)');
      }
      rethrow;
    }

    // Sauvegarder les métadonnées
    if (firstSnapshot != null && lastSnapshot != null) {
      final fileSize = await sessionFile.length();
      print('📊 [TelemetryStorage] Taille fichier final: ${fileSize} bytes');
      print('📊 [TelemetryStorage] Total snapshots: $snapshotCount');
      print('📊 [TelemetryStorage] Durée: ${lastSnapshot.difference(firstSnapshot).inSeconds}s');
      
      final metadata = SessionMetadata(
        sessionId: sessionId,
        startTime: firstSnapshot,
        endTime: lastSnapshot,
        snapshotCount: snapshotCount,
        sizeBytes: fileSize.toInt(),
      );

      await _saveMetadata(sessionId, metadata);
      print('✅ [TelemetryStorage] Session sauvegardée avec succès!');
    } else {
      print('⚠️ [TelemetryStorage] Pas de snapshots enregistrés');
    }
  }

  @override
  Future<List<TelemetrySnapshot>> loadSession(String sessionId) async {
    print('📂 [loadSession] Chargement session: $sessionId');
    
    final sessionFile = File(_sessionFilePath(sessionId));
    if (!await sessionFile.exists()) {
      print('❌ [loadSession] Fichier n\'existe pas: ${sessionFile.path}');
      throw Exception('Session $sessionId not found');
    }

    final fileSize = await sessionFile.length();
    print('📂 [loadSession] Fichier trouvé, taille: $fileSize bytes');

    final snapshots = <TelemetrySnapshot>[];
    int lineCount = 0;
    int errorCount = 0;
    
    print('🔄 [loadSession] Démarrage décompression et parsing...');
    
    try {
      final input = sessionFile.openRead();
      final decompressed = input.transform(GZipCodec().decoder);
      final lines = decompressed
          .transform(const Utf8Decoder())
          .transform(const LineSplitter());

      await for (final line in lines) {
        lineCount++;
        if (line.trim().isEmpty) continue;
        try {
          final snapshot = _jsonLineToSnapshot(line);
          snapshots.add(snapshot);
        } catch (e) {
          errorCount++;
          print('⚠️ [loadSession] Erreur parsing ligne $lineCount: $e');
          // Continuer avec les autres snapshots
        }
      }
      print('✅ [loadSession] Décompression terminée');
    } catch (e, st) {
      print('❌ [loadSession] Erreur décompression: $e');
      print('   StackTrace: $st');
      rethrow;
    }

    print('✅ [loadSession] Chargement complet:');
    print('   - Lignes lues: $lineCount');
    print('   - Snapshots parsés: ${snapshots.length}');
    print('   - Erreurs: $errorCount');
    if (snapshots.isNotEmpty) {
      print('   - Premier: ${snapshots.first.ts}');
      print('   - Dernier: ${snapshots.last.ts}');
      print('   - Durée: ${snapshots.last.ts.difference(snapshots.first.ts).inSeconds}s');
    }

    return snapshots;
  }

  @override
  Future<List<TelemetrySnapshot>> loadSessionFiltered(
    String sessionId,
    SessionLoadFilter filter,
  ) async {
    // Charger la session complète (pas d'optimisation JSON)
    final snapshots = await loadSession(sessionId);

    // Appliquer les filtres
    Iterable<TelemetrySnapshot> result = snapshots;

    // Filtre de temps
    if (filter.startTime != null) {
      result = result.where((s) => s.ts.isAfter(filter.startTime!));
    }
    if (filter.endTime != null) {
      result = result.where((s) => s.ts.isBefore(filter.endTime!));
    }

    // Filtre de métriques
    if (filter.metricKeyFilter != null) {
      result = result.map((snapshot) {
        final filteredMetrics = <String, Measurement>{};
        final pattern = _globToRegex(filter.metricKeyFilter!);

        for (final entry in snapshot.metrics.entries) {
          if (pattern.hasMatch(entry.key)) {
            filteredMetrics[entry.key] = entry.value;
          }
        }

        return TelemetrySnapshot(
          ts: snapshot.ts,
          metrics: filteredMetrics,
          tags: snapshot.tags,
        );
      });
    }

    // Pagination
    var list = result.toList();
    if (filter.offset > 0) {
      list = list.skip(filter.offset).toList();
    }
    if (filter.limit != null) {
      list = list.take(filter.limit!).toList();
    }

    return list;
  }

  @override
  Future<List<SessionMetadata>> listSessions() async {
    await _ensureDirectories();

    final sessions = <SessionMetadata>[];
    final sessionsDir = _sessionsDir;

    try {
      await for (final entity in sessionsDir.list()) {
        if (entity is! File) continue;

        final fileName = path.basename(entity.path);
        if (!fileName.endsWith('.jsonl.gz')) continue;

        final sessionId = fileName.replaceAll('.jsonl.gz', '');

        try {
          final metadata = await getSessionMetadata(sessionId);
          sessions.add(metadata);
        } catch (e) {
          print('⚠️ Erreur chargement métadonnées $sessionId: $e');
        }
      }
    } catch (e) {
      print('⚠️ Erreur listage sessions: $e');
    }

    // Trier par date décroissante (plus récent en premier)
    sessions.sort((a, b) => b.startTime.compareTo(a.startTime));
    return sessions;
  }

  @override
  Future<SessionMetadata> getSessionMetadata(String sessionId) async {
    // Essayer charger les métadonnées en cache
    final metadataFile = File(_metadataFilePath(sessionId));
    if (await metadataFile.exists()) {
      try {
        final json = jsonDecode(await metadataFile.readAsString());
        return _jsonToSessionMetadata(json, sessionId);
      } catch (e) {
        print('⚠️ Erreur chargement métadonnées en cache: $e');
      }
    }

    // Sinon, scanner le fichier pour récupérer les infos
    final sessionFile = File(_sessionFilePath(sessionId));
    if (!await sessionFile.exists()) {
      throw Exception('Session $sessionId not found');
    }

    DateTime? firstTs;
    DateTime? lastTs;
    int count = 0;

    try {
      final input = sessionFile.openRead();
      final decompressed = input.transform(GZipCodec().decoder);
      final lines = decompressed
          .transform(const Utf8Decoder())
          .transform(const LineSplitter());

      await for (final line in lines) {
        if (line.trim().isEmpty) continue;
        try {
          final json = jsonDecode(line);
          final ts = DateTime.parse(json['ts']);
          firstTs ??= ts;
          lastTs = ts;
          count++;
        } catch (_) {
          // Ignorer les lignes mal formées
        }
      }
    } catch (e) {
      throw Exception('Erreur lecture session $sessionId: $e');
    }

    if (firstTs == null || lastTs == null) {
      throw Exception('Session $sessionId est vide ou invalide');
    }

    final fileSize = (await sessionFile.length()).toInt();
    final metadata = SessionMetadata(
      sessionId: sessionId,
      startTime: firstTs,
      endTime: lastTs,
      snapshotCount: count,
      sizeBytes: fileSize,
    );

    // Sauvegarder les métadonnées en cache
    try {
      await _saveMetadata(sessionId, metadata);
    } catch (_) {
      // Ignorer les erreurs de cache
    }

    return metadata;
  }

  @override
  Future<SessionStats> getSessionStats(String sessionId) async {
    print('📊 [TelemetryStorage.getSessionStats] Lecture stats pour session: $sessionId');
    
    final sessionFile = File(_sessionFilePath(sessionId));
    print('📂 [TelemetryStorage.getSessionStats] Fichier: ${sessionFile.path}');
    print('   Existe? ${await sessionFile.exists()}');
    
    if (await sessionFile.exists()) {
      final fileSize = await sessionFile.length();
      print('   Taille: $fileSize bytes');
    }
    
    final snapshots = await loadSession(sessionId);
    print('✅ [TelemetryStorage.getSessionStats] Chargé ${snapshots.length} snapshots');

    if (snapshots.isEmpty) {
      print('⚠️ [TelemetryStorage.getSessionStats] Aucun snapshot trouvé');
      throw Exception('Session $sessionId est vide');
    }

    double sumSpeed = 0;
    double maxSpeed = 0;
    double minSpeed = double.infinity;
    double sumWindSpeed = 0;
    double maxWindSpeed = 0;
    double minWindSpeed = double.infinity;
    int windCount = 0;

    print('📈 [TelemetryStorage.getSessionStats] Calcul stats sur ${snapshots.length} snapshots...');
    
    for (final snapshot in snapshots) {
      // Vitesse (nav.sog)
      final sog = snapshot.metrics['nav.sog']?.value;
      if (sog != null) {
        sumSpeed += sog;
        maxSpeed = maxSpeed < sog ? sog : maxSpeed;
        minSpeed = minSpeed > sog ? sog : minSpeed;
      }

      // Vitesse vent (wind.tws)
      final tws = snapshot.metrics['wind.tws']?.value;
      if (tws != null) {
        sumWindSpeed += tws;
        maxWindSpeed = maxWindSpeed < tws ? tws : maxWindSpeed;
        minWindSpeed = minWindSpeed > tws ? tws : minWindSpeed;
        windCount++;
      }
    }

    // Calculer la durée d'enregistrement
    int? durationSeconds;
    if (snapshots.length > 1) {
      final firstTs = snapshots.first.ts;
      final lastTs = snapshots.last.ts;
      durationSeconds = lastTs.difference(firstTs).inSeconds;
    }

    final stats = SessionStats(
      sessionId: sessionId,
      avgSpeed: sumSpeed / snapshots.length,
      maxSpeed: maxSpeed,
      minSpeed: minSpeed == double.infinity ? 0 : minSpeed,
      avgWindSpeed: windCount > 0 ? sumWindSpeed / windCount : 0,
      maxWindSpeed: maxWindSpeed == 0 ? 0 : maxWindSpeed,
      minWindSpeed: minWindSpeed == double.infinity ? 0 : minWindSpeed,
      snapshotCount: snapshots.length,
      durationSeconds: durationSeconds,
    );
    
    print('✅ [TelemetryStorage.getSessionStats] Stats calculées:');
    print('   Speed: AVG=${stats.avgSpeed.toStringAsFixed(1)}, MAX=${stats.maxSpeed.toStringAsFixed(1)}');
    print('   Wind: AVG=${stats.avgWindSpeed.toStringAsFixed(1)}, MAX=${stats.maxWindSpeed.toStringAsFixed(1)}, MIN=${stats.minWindSpeed.toStringAsFixed(1)}');
    print('   Duration: ${stats.durationSeconds}s');
    
    return stats;
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    final sessionFile = File(_sessionFilePath(sessionId));
    final metadataFile = File(_metadataFilePath(sessionId));

    if (!await sessionFile.exists()) {
      throw Exception('Session $sessionId not found');
    }

    await sessionFile.delete();
    if (await metadataFile.exists()) {
      await metadataFile.delete();
    }
  }

  @override
  Future<bool> sessionExists(String sessionId) async {
    return await File(_sessionFilePath(sessionId)).exists();
  }

  @override
  Future<void> exportSession({
    required String sessionId,
    required String format,
    required String outputPath,
  }) async {
    final snapshots = await loadSession(sessionId);

    switch (format.toLowerCase()) {
      case 'json':
        await _exportJson(snapshots, outputPath);
        break;
      case 'csv':
        await _exportCsv(snapshots, outputPath);
        break;
      case 'jsonl':
        await _exportJsonL(snapshots, outputPath);
        break;
      default:
        throw Exception('Format $format non supporté. Utilisez: json, csv, jsonl');
    }
  }

  @override
  Future<int> getSessionSizeBytes(String sessionId) async {
    final sessionFile = File(_sessionFilePath(sessionId));
    if (!await sessionFile.exists()) {
      throw Exception('Session $sessionId not found');
    }
    return (await sessionFile.length()).toInt();
  }

  @override
  Future<int> getTotalSizeBytes() async {
    int total = 0;
    final sessions = await listSessions();
    for (final session in sessions) {
      total += session.sizeBytes;
    }
    return total;
  }

  @override
  Future<int> cleanupOldSessions({required int olderThanDays}) async {
    final cutoff = DateTime.now().subtract(Duration(days: olderThanDays));
    final sessions = await listSessions();
    int deleted = 0;

    for (final session in sessions) {
      if (session.startTime.isBefore(cutoff)) {
        try {
          await deleteSession(session.sessionId);
          deleted++;
        } catch (e) {
          print('⚠️ Erreur suppression session ${session.sessionId}: $e');
        }
      }
    }

    return deleted;
  }

  // ============================================================================
  // Helpers privés
  // ============================================================================

  String _snapshotToJsonLine(TelemetrySnapshot snapshot) {
    final metricsMap = <String, double>{};
    for (final entry in snapshot.metrics.entries) {
      metricsMap[entry.key] = entry.value.value;
    }

    final json = {
      'ts': snapshot.ts.toIso8601String(),
      'metrics': metricsMap,
      if (snapshot.tags.isNotEmpty) 'tags': snapshot.tags,
    };

    return jsonEncode(json);
  }

  TelemetrySnapshot _jsonLineToSnapshot(String line) {
    try {
      final decoded = jsonDecode(line);
      
      // Convertir Map<dynamic, dynamic> en Map<String, dynamic>
      final json = (decoded as Map).cast<String, dynamic>();

      final ts = DateTime.parse(json['ts'] as String);
      final metricsRaw = json['metrics'] ?? {};
      final tagsRaw = json['tags'] ?? {};
      
      // Convertir metrics en Map<String, dynamic>
      final metricsJson = (metricsRaw as Map).cast<String, dynamic>();
      final tagsJson = (tagsRaw as Map).cast<String, dynamic>();

      final metrics = <String, Measurement>{};
      for (final entry in metricsJson.entries) {
        metrics[entry.key] = Measurement(
          value: (entry.value as num).toDouble(),
          unit: _guessUnit(entry.key),
          ts: ts,
        );
      }

      return TelemetrySnapshot(
        ts: ts,
        metrics: metrics,
        tags: tagsJson,
      );
    } catch (e) {
      print('❌ [_jsonLineToSnapshot] Erreur parsing: $e');
      print('   Ligne: $line');
      rethrow;
    }
  }

  Unit _guessUnit(String key) {
    // Heuristique simple pour deviner l'unité d'après la clé
    if (key.contains('tws') || key.contains('aws') || key.contains('sog') || key.contains('cog')) {
      return Unit.knot;
    }
    if (key.contains('twd') || key.contains('twa') || key.contains('awa') || key.contains('hdg')) {
      return Unit.degree;
    }
    if (key.contains('depth') || key.contains('lat') || key.contains('lon')) {
      return Unit.meter;
    }
    if (key.contains('temp') || key.contains('waterTemp')) {
      return Unit.celsius;
    }
    return Unit.none;
  }

  Future<void> _saveMetadata(
    String sessionId,
    SessionMetadata metadata,
  ) async {
    await _metadataDir.create(recursive: true);
    final metadataFile = File(_metadataFilePath(sessionId));

    final json = {
      'sessionId': metadata.sessionId,
      'startTime': metadata.startTime.toIso8601String(),
      'endTime': metadata.endTime.toIso8601String(),
      'snapshotCount': metadata.snapshotCount,
      'sizeBytes': metadata.sizeBytes,
    };

    await metadataFile.writeAsString(jsonEncode(json));
  }

  SessionMetadata _jsonToSessionMetadata(
    Map<String, dynamic> json,
    String sessionId,
  ) {
    return SessionMetadata(
      sessionId: json['sessionId'] ?? sessionId,
      startTime: DateTime.parse(json['startTime']),
      endTime: DateTime.parse(json['endTime']),
      snapshotCount: json['snapshotCount'],
      sizeBytes: json['sizeBytes'],
    );
  }

  Future<void> _exportJson(
    List<TelemetrySnapshot> snapshots,
    String outputPath,
  ) async {
    final output = snapshots
        .map((s) => {
              'ts': s.ts.toIso8601String(),
              'metrics': s.metrics.map((k, v) => MapEntry(k, v.value)),
            })
        .toList();

    final file = File(outputPath);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(output));
  }

  Future<void> _exportJsonL(
    List<TelemetrySnapshot> snapshots,
    String outputPath,
  ) async {
    final file = File(outputPath);
    final sink = file.openWrite();

    for (final snapshot in snapshots) {
      sink.writeln(_snapshotToJsonLine(snapshot));
    }

    await sink.close();
  }

  Future<void> _exportCsv(
    List<TelemetrySnapshot> snapshots,
    String outputPath,
  ) async {
    if (snapshots.isEmpty) {
      final file = File(outputPath);
      await file.writeAsString('# Pas de données\n');
      return;
    }

    // Déterminer toutes les colonnes uniques
    final columns = <String>{'ts'};
    for (final snapshot in snapshots) {
      columns.addAll(snapshot.metrics.keys);
    }

    final file = File(outputPath);
    final sink = file.openWrite();

    // En-tête
    sink.writeln(columns.join(','));

    // Données
    for (final snapshot in snapshots) {
      final row = <String>[snapshot.ts.toIso8601String()];
      for (final col in columns.skip(1)) {
        final value = snapshot.metrics[col]?.value ?? '';
        row.add(value.toString());
      }
      sink.writeln(row.join(','));
    }

    await sink.close();
  }

  RegExp _globToRegex(String glob) {
    // Convertir un pattern glob simple en regex
    // Ex: "wind.*" → regex qui match "wind.twd", "wind.tws", etc.
    final pattern = glob
        .replaceAll('.', '\\.')
        .replaceAll('*', '.*')
        .replaceAll('?', '.');
    return RegExp('^$pattern\$');
  }
}
