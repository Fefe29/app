import 'package:kornog/data/datasources/gribs/grib_interpolation_service.dart';
import 'package:kornog/data/datasources/gribs/grib_models.dart';
import 'package:kornog/features/charts/domain/models/geographic_position.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Position géographique + vent à ce point
class WindPoint {
  final GeographicPosition position;
  final WindVector? wind;
  
  WindPoint({
    required this.position,
    this.wind,
  });
  
  /// Vitesse du vent en m/s (0 si pas de données)
  double get windSpeed => wind?.speed ?? 0.0;
  
  /// Direction du vent en degrés (0 si pas de données)
  double get windDirection => wind?.direction ?? 0.0;
  
  @override
  String toString() => 'WindPoint(${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}) -> $wind';
}

/// Service qui génère un grid de 50 points uniformément répartis
/// dans le viewport courant et récupère le vent à chaque point
class ViewportWindGrid {
  /// Grille 10x5 = 50 points
  static const int pointsHorizontal = 10; // 10 colonnes
  static const int pointsVertical = 5;    // 5 lignes
  static const int totalPoints = pointsHorizontal * pointsVertical; // 50 points

  /// Génère les 10 points dans le viewport courant
  /// 
  /// [minLon, maxLon, minLat, maxLat] - bounds géographiques du viewport
  /// [uGrids, vGrids, timestamps, time] - données GRIB pour interpolation
  /// 
  /// Retourne une liste de WindPoints ordonnés de gauche à droite, haut en bas
  static Future<List<WindPoint>> generateWindPoints({
    required double minLon,
    required double maxLon,
    required double minLat,
    required double maxLat,
    required List<ScalarGrid> uGrids,
    required List<ScalarGrid> vGrids,
    required List<DateTime> timestamps,
    required DateTime forecastTime,
  }) async {
    print('[VIEWPORT_GRID] Generating wind points: lon=$minLon..$maxLon, lat=$minLat..$maxLat');
    
    // Générer les positions géographiques en grille
    final positions = _generateGridPositions(
      minLon: minLon,
      maxLon: maxLon,
      minLat: minLat,
      maxLat: maxLat,
    );

    print('[VIEWPORT_GRID] Generated ${positions.length} positions');

    // Interroger le vent à chaque position
    final points = [
      for (final p in positions) (p.longitude, p.latitude),
    ];
    final windVectors = GribInterpolationService.getWindAtMultiplePoints(
      uGrids: uGrids,
      vGrids: vGrids,
      timestamps: timestamps,
      points: points,
      time: forecastTime,
    );

    print('[VIEWPORT_GRID] Got ${windVectors.length} wind vectors');

    // Combiner positions et vents
    return [
      for (int i = 0; i < positions.length; i++)
        WindPoint(
          position: positions[i],
          wind: windVectors[i],
        )
    ];
  }

  /// Génère les positions géographiques en grille 5x2
  /// Points ordonnés: 
  /// - de haut à bas (1ère ligne, puis 2ème ligne)
  /// - de gauche à droite (minLon → maxLon)
  static List<GeographicPosition> _generateGridPositions({
    required double minLon,
    required double maxLon,
    required double minLat,
    required double maxLat,
  }) {
    final positions = <GeographicPosition>[];
    
    final dLon = (maxLon - minLon) / (pointsHorizontal - 1);
    final dLat = (maxLat - minLat) / (pointsVertical - 1);
    
    // Parcourir de haut en bas
    for (int j = 0; j < pointsVertical; j++) {
      final lat = maxLat - j * dLat;
      
      // Parcourir de gauche à droite
      for (int i = 0; i < pointsHorizontal; i++) {
        final lon = minLon + i * dLon;
        positions.add(GeographicPosition(latitude: lat, longitude: lon));
      }
    }
    
    return positions;
  }

  /// 🆕 NOUVELLE MÉTHODE: Génère 10 points uniformément espacés en PIXELS
  /// Chaque pixel est converti en position géographique
  /// 
  /// [canvasSize] - dimensions du canvas (Size.width, Size.height)
  /// [view] - ViewTransform contenant minX/maxX/minY/maxY et scale/offset
  /// [mercatorService] - service pour convertir local → géographique
  /// [uGrids, vGrids, timestamps, time] - données GRIB
  static Future<List<WindPoint>> generateWindPointsFromPixels({
    required Size canvasSize,
    required dynamic view, // ViewTransform (on peut pas l'importer ici)
    required dynamic mercatorService, // MercatorCoordinateSystemService
    required List<ScalarGrid> uGrids,
    required List<ScalarGrid> vGrids,
    required List<DateTime> timestamps,
    required DateTime forecastTime,
  }) async {
    // Générer les 10 positions en pixels (grille 5x2)
    final pixelPositions = _generateGridPixelPositions(canvasSize);
    
    // Convertir chaque pixel → local → géographique
    final geoPositions = <GeographicPosition>[];
    for (final pixelPos in pixelPositions) {
      // Inverse project: pixel → local
      final localX = (pixelPos.dx - view.offsetX) / view.scale + view.minX;
      final localY = (canvasSize.height - pixelPos.dy - view.offsetY) / view.scale + view.minY;
      
      // Local → geographic
      final geoPos = mercatorService.toGeographic(LocalPosition(x: localX, y: localY));
      geoPositions.add(geoPos);
    }

    // Interroger le vent à tous les points géographiques
    final points = [
      for (final p in geoPositions) (p.longitude, p.latitude),
    ];
    final windVectors = GribInterpolationService.getWindAtMultiplePoints(
      uGrids: uGrids,
      vGrids: vGrids,
      timestamps: timestamps,
      points: points,
      time: forecastTime,
    );

    // Combiner positions et vents
    return [
      for (int i = 0; i < geoPositions.length; i++)
        WindPoint(
          position: geoPositions[i],
          wind: windVectors[i],
        )
    ];
  }

  /// Génère les 10 positions en pixels uniformément réparties (grille 5x2)
  static List<Offset> _generateGridPixelPositions(Size canvasSize) {
    final positions = <Offset>[];
    
    // Marge autour de l'écran pour éviter les bords
    const marginPercent = 0.1; // 10% de marge de chaque côté
    final marginX = canvasSize.width * marginPercent;
    final marginY = canvasSize.height * marginPercent;
    
    final effectiveWidth = canvasSize.width - 2 * marginX;
    final effectiveHeight = canvasSize.height - 2 * marginY;
    
    // Espacement horizontal et vertical
    final dX = effectiveWidth / (pointsHorizontal - 1);
    final dY = effectiveHeight / (pointsVertical - 1);
    
    // Générer les positions (de haut en bas, de gauche à droite)
    for (int j = 0; j < pointsVertical; j++) {
      final y = marginY + j * dY;
      
      for (int i = 0; i < pointsHorizontal; i++) {
        final x = marginX + i * dX;
        positions.add(Offset(x, y));
      }
    }
    
    return positions;
  }

  /// Calcule les bounds géographiques du viewport donné une ViewTransform
  /// Cette méthode doit être appelée avec l'info du ViewTransform courant
  /// 
  /// [viewMinX, viewMaxX, viewMinY, viewMaxY] - bounds locales du viewport (Mercator)
  /// [mercatorService] - service pour convertir local → géographique
  static List<GeographicPosition> getViewportCorners({
    required double viewMinX,
    required double viewMaxX,
    required double viewMinY,
    required double viewMaxY,
  }) {
    // Les coins du viewport en coordonnées locales Mercator
    return [
      // Top-left
      GeographicPosition(latitude: 0, longitude: 0), // Placeholder
      // Top-right
      GeographicPosition(latitude: 0, longitude: 0),
      // Bottom-left
      GeographicPosition(latitude: 0, longitude: 0),
      // Bottom-right
      GeographicPosition(latitude: 0, longitude: 0),
    ];
  }
}

/// Extension helper pour accéder facilement au vent aux 10 points
extension WindPointList on List<WindPoint> {
  /// Retourne la liste des (longitude, latitude) pour interroger le vent
  List<(double, double)> get positions => 
      map((p) => (p.position.longitude, p.position.latitude)).toList();
  
  /// Retourne la vitesse moyenne du vent
  double get averageWindSpeed {
    final nonNull = where((p) => p.wind != null);
    if (nonNull.isEmpty) return 0.0;
    return nonNull.map((p) => p.windSpeed).reduce((a, b) => a + b) / nonNull.length;
  }
  
  /// Retourne la direction moyenne (attention: moyenne de vecteurs, pas de degrés!)
  double get averageWindDirection {
    final nonNull = where((p) => p.wind != null);
    if (nonNull.isEmpty) return 0.0;
    
    double sumU = 0, sumV = 0;
    for (final p in nonNull) {
      final wind = p.wind!;
      final radians = wind.direction * math.pi / 180.0;
      sumU += wind.speed * math.sin(radians);
      sumV += wind.speed * math.cos(radians);
    }
    
    final resultRadians = math.atan2(sumU, sumV);
    return (resultRadians * 180.0 / math.pi + 360) % 360;
  }
}
