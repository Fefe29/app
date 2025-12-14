/// Modèles pour les tuiles de carte et métadonnées de téléchargement.
import 'map_bounds.dart';

/// Source des données de carte
enum MapSource {
  local,    // Cartes téléchargées et stockées localement
  oceam,    // OSeaM Standard (streaming via API)
}

/// États de téléchargement d'une carte
enum MapDownloadStatus {
  notStarted,   // Pas encore commencé
  downloading,  // En cours de téléchargement
  completed,    // Téléchargement terminé avec succès
  failed,       // Échec du téléchargement
  cancelled,    // Annulé par l'utilisateur
  streaming     // Flux continu (OSeaM)
}

/// Informations sur une carte téléchargée ou à télécharger
class MapTileSet {
  const MapTileSet({
    required this.id,
    required this.name,
    required this.bounds,
    required this.zoomLevel,
    required this.status,
    this.description,
    this.downloadedAt,
    this.fileSizeBytes,
    this.tileCount,
    this.downloadProgress = 0.0,
    this.errorMessage,
    this.source = MapSource.local,
  });

  final String id;                    // Identifiant unique
  final String name;                  // Nom donné par l'utilisateur
  final MapBounds bounds;             // Zone géographique couverte
  final int zoomLevel;                // Niveau de zoom (8-18 typiquement)
  final MapDownloadStatus status;     // État du téléchargement
  final String? description;          // Description optionnelle
  final DateTime? downloadedAt;       // Date de téléchargement
  final int? fileSizeBytes;          // Taille totale en octets
  final int? tileCount;              // Nombre de tuiles
  final double downloadProgress;      // Progrès 0.0 à 1.0
  final String? errorMessage;        // Message d'erreur si échec
  final MapSource source;             // Source de la carte (local ou OSeaM)

  /// Taille formatée pour l'affichage
  String get formattedSize {
    if (fileSizeBytes == null) return 'Inconnue';
    
    final bytes = fileSizeBytes!;
    if (bytes < 1024) return '${bytes} B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Progrès formaté en pourcentage
  String get formattedProgress => '${(downloadProgress * 100).toStringAsFixed(1)}%';

  /// Estimation du nombre de tuiles pour une zone et un niveau de zoom
  static int estimateTileCount(MapBounds bounds, int zoomLevel) {
    // Formule approximative pour le nombre de tuiles OSM
    final latRange = bounds.heightDegrees;
    final lonRange = bounds.widthDegrees;
    
    // À chaque niveau de zoom, le nombre de tuiles double dans chaque direction
    final tilesPerDegree = (1 << zoomLevel) / 360.0;
    
    final tilesLat = (latRange * tilesPerDegree).ceil();
    final tilesLon = (lonRange * tilesPerDegree).ceil();
    
    return tilesLat * tilesLon;
  }

  /// Estimation de la taille en octets
  static int estimateSizeBytes(MapBounds bounds, int zoomLevel) {
    final tileCount = estimateTileCount(bounds, zoomLevel);
    const averageTileSize = 15000; // ~15KB par tuile en moyenne
    return tileCount * averageTileSize;
  }

  MapTileSet copyWith({
    String? id,
    String? name,
    MapBounds? bounds,
    int? zoomLevel,
    MapDownloadStatus? status,
    String? description,
    DateTime? downloadedAt,
    int? fileSizeBytes,
    int? tileCount,
    double? downloadProgress,
    String? errorMessage,
    MapSource? source,
  }) => MapTileSet(
        id: id ?? this.id,
        name: name ?? this.name,
        bounds: bounds ?? this.bounds,
        zoomLevel: zoomLevel ?? this.zoomLevel,
        status: status ?? this.status,
        description: description ?? this.description,
        downloadedAt: downloadedAt ?? this.downloadedAt,
        fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
        tileCount: tileCount ?? this.tileCount,
        downloadProgress: downloadProgress ?? this.downloadProgress,
        errorMessage: errorMessage ?? this.errorMessage,
        source: source ?? this.source,
      );

  @override
  String toString() => 'MapTileSet($name, $bounds, zoom:$zoomLevel, $status)';
}

/// Configuration pour le téléchargement de cartes
class MapDownloadConfig {
  const MapDownloadConfig({
    required this.bounds,
    required this.zoomLevel,
    required this.name,
    this.description,
    this.tileServer = 'https://tile.openstreetmap.org',
    this.maxConcurrentDownloads = 4,
    this.retryAttempts = 3,
    this.requestDelay = const Duration(milliseconds: 100),
  });

  final MapBounds bounds;              // Zone à télécharger
  final int zoomLevel;                 // Niveau de zoom
  final String name;                   // Nom de la carte
  final String? description;           // Description
  final String tileServer;             // Serveur de tuiles
  final int maxConcurrentDownloads;    // Téléchargements simultanés
  final int retryAttempts;             // Tentatives de retry
  final Duration requestDelay;         // Délai entre requêtes

  /// Validation de la configuration
  List<String> validate() {
    final errors = <String>[];
    
    if (name.trim().isEmpty) {
      errors.add('Le nom ne peut pas être vide');
    }
    
    if (zoomLevel < 1 || zoomLevel > 18) {
      errors.add('Le niveau de zoom doit être entre 1 et 18');
    }
    
    if (bounds.widthDegrees <= 0 || bounds.heightDegrees <= 0) {
      errors.add('Les limites de la zone sont invalides');
    }
    
    final estimatedTiles = MapTileSet.estimateTileCount(bounds, zoomLevel);
    if (estimatedTiles > 150000) {
      errors.add('Zone trop grande (${estimatedTiles} tuiles estimées, max 150k)');
    }
    
    return errors;
  }

  /// Estimation de la taille de téléchargement
  String get estimatedSize => MapTileSet.estimateSizeBytes(bounds, zoomLevel).toString();
}