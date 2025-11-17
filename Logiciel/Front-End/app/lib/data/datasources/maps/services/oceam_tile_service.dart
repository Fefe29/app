/// Service pour récupérer les tuiles OSeaM via API
/// Support du standard OSeaM disponible sur oSeaMap.org

import 'package:http/http.dart' as http;
import 'dart:typed_data';

/// Configuration OSeaM
class OSeaMConfig {
  const OSeaMConfig({
    this.tileBaseUrl = 'https://tiles.openseamap.org/seamark',
    this.timeout = const Duration(seconds: 10),
    this.cacheSize = 100, // nombre de tuiles à garder en cache
  });

  final String tileBaseUrl;        // URL de base pour les tuiles
  final Duration timeout;          // Timeout des requêtes HTTP
  final int cacheSize;             // Taille du cache en mémoire
}

/// Cache simple pour les tuiles téléchargées
class _TileCache {
  _TileCache(this.maxSize);

  final int maxSize;
  final Map<String, Uint8List> _cache = {};

  bool has(String key) => _cache.containsKey(key);

  Uint8List? get(String key) => _cache[key];

  void set(String key, Uint8List data) {
    if (_cache.length >= maxSize) {
      // Supprimer la première entrée si cache plein
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = data;
  }

  void clear() => _cache.clear();

  int get size => _cache.length;
}

/// Service de récupération des tuiles OSeaM
class OSeaMTileService {
  OSeaMTileService({
    OSeaMConfig config = const OSeaMConfig(),
  })  : _config = config,
        _cache = _TileCache(config.cacheSize),
        _httpClient = http.Client();

  final OSeaMConfig _config;
  final _TileCache _cache;
  final http.Client _httpClient;
  int _requestCount = 0;

  /// Récupère une tuile OSeaM par ses coordonnées
  /// Returns: Données PNG de la tuile, ou null si erreur
  Future<Uint8List?> getTile(int x, int y, int z) async {
    final cacheKey = '$z/$x/$y';

    // Vérifier le cache
    if (_cache.has(cacheKey)) {
      return _cache.get(cacheKey);
    }

    try {
      // Respecter le rate limiting (500ms entre requêtes)
      await Future.delayed(const Duration(milliseconds: 100));

      final url = '${_config.tileBaseUrl}/$z/$x/$y.png';
      final response = await _httpClient.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Kornog/1.0 (OSeaM Tile Fetcher)',
        },
      ).timeout(_config.timeout);

      _requestCount++;

      if (response.statusCode == 200) {
        final data = response.bodyBytes;
        // Cacher la tuile
        _cache.set(cacheKey, data);
        return data;
      } else {
        print('[OSeaM] Erreur tuile $cacheKey: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('[OSeaM] Exception fetch tuile $cacheKey: $e');
      return null;
    }
  }

  /// Récupère plusieurs tuiles en parallèle (avec limitation)
  Future<Map<String, Uint8List?>> getTiles(
    List<(int, int, int)> coordinates, {
    int maxConcurrent = 4,
  }) async {
    final result = <String, Uint8List?>{};

    // Traiter par chunks pour respecter le rate limiting
    for (var i = 0; i < coordinates.length; i += maxConcurrent) {
      final chunk = coordinates.sublist(
        i,
        i + maxConcurrent > coordinates.length
            ? coordinates.length
            : i + maxConcurrent,
      );

      final futures = chunk.map((coord) async {
        final (x, y, z) = coord;
        final key = '$z/$x/$y';
        final data = await getTile(x, y, z);
        return MapEntry(key, data);
      });

      final chunkResults = await Future.wait(futures);
      result.addAll(Map.fromEntries(chunkResults));

      // Petit délai entre chunks
      if (i + maxConcurrent < coordinates.length) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }

    return result;
  }

  /// Retourne des statistiques sur le service
  Map<String, dynamic> getStats() => {
        'requestCount': _requestCount,
        'cacheSize': _cache.size,
        'cacheMaxSize': _config.cacheSize,
      };

  /// Nettoie le cache
  void clearCache() => _cache.clear();

  /// Ferme le service
  void dispose() {
    _httpClient.close();
    _cache.clear();
  }
}
