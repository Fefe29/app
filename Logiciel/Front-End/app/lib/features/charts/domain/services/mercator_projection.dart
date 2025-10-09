/// Service de projection Mercator unifié pour les cartes et les bouées
import 'dart:math' as math;
import '../models/geographic_position.dart';

/// Point en coordonnées Mercator Web (EPSG:3857) en mètres
class MercatorPoint {
  const MercatorPoint({required this.x, required this.y});
  
  final double x; // Mètres est depuis origine
  final double y; // Mètres nord depuis origine
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MercatorPoint && x == other.x && y == other.y;
  
  @override
  int get hashCode => x.hashCode ^ y.hashCode;
  
  @override
  String toString() => 'MercatorPoint(x: ${x.toStringAsFixed(1)}m, y: ${y.toStringAsFixed(1)}m)';
}

/// Service de projection Mercator Web unifié
class MercatorProjection {
  static const double _earthRadius = 6378137.0; // Rayon équatorial WGS84 en mètres
  static const double _originShift = math.pi * _earthRadius; // 20037508.342789244
  
  /// Convertit latitude/longitude WGS84 vers coordonnées Mercator Web en mètres
  static MercatorPoint geographicToMercator(GeographicPosition geo) {
    final x = geo.longitude * _originShift / 180.0;
    var y = math.log(math.tan((90.0 + geo.latitude) * math.pi / 360.0)) / (math.pi / 180.0);
    y = y * _originShift / 180.0;
    
    return MercatorPoint(x: x, y: y);
  }
  
  /// Convertit coordonnées Mercator Web vers latitude/longitude WGS84
  static GeographicPosition mercatorToGeographic(MercatorPoint mercator) {
    final lon = (mercator.x / _originShift) * 180.0;
    var lat = (mercator.y / _originShift) * 180.0;
    lat = 180.0 / math.pi * (2.0 * math.atan(math.exp(lat * math.pi / 180.0)) - math.pi / 2.0);
    
    return GeographicPosition(latitude: lat, longitude: lon);
  }
  
  /// Convertit coordonnées de tuile OSM vers Mercator Web
  static MercatorPoint tileToMercator(int tileX, int tileY, int zoom) {
    final n = math.pow(2, zoom);
    final lon = tileX / n * 360.0 - 180.0;
    
    // Utiliser la formule standard de décodage OSM/Mercator
    final latRad = math.atan(_sinh(math.pi * (1 - 2 * tileY / n)));
    final lat = latRad * 180.0 / math.pi;
    
    return geographicToMercator(GeographicPosition(latitude: lat, longitude: lon));
  }
  
  /// Fonction sinh manuelle (sinus hyperbolique)
  static double _sinh(double x) {
    return (math.exp(x) - math.exp(-x)) / 2.0;
  }
  
  /// Calcule la résolution en mètres par pixel pour un niveau de zoom donné
  static double resolutionAtZoom(int zoom) {
    return 2 * _originShift / (256 * math.pow(2, zoom));
  }
}

/// Système de coordonnées unifié basé sur Mercator
class UnifiedCoordinateSystem {
  UnifiedCoordinateSystem({required this.origin});
  
  final GeographicPosition origin;
  late final MercatorPoint _originMercator = MercatorProjection.geographicToMercator(origin);
  
  /// Convertit position géographique vers coordonnées locales en mètres depuis l'origine
  LocalPosition geographicToLocal(GeographicPosition geo) {
    final mercator = MercatorProjection.geographicToMercator(geo);
    return LocalPosition(
      x: mercator.x - _originMercator.x,
      y: mercator.y - _originMercator.y,
    );
  }
  
  /// Convertit coordonnées locales vers position géographique
  GeographicPosition localToGeographic(LocalPosition local) {
    final mercator = MercatorPoint(
      x: _originMercator.x + local.x,
      y: _originMercator.y + local.y,
    );
    return MercatorProjection.mercatorToGeographic(mercator);
  }
  
  /// Convertit tuile OSM vers coordonnées locales
  LocalPosition tileToLocal(int tileX, int tileY, int zoom) {
    final mercator = MercatorProjection.tileToMercator(tileX, tileY, zoom);
    return LocalPosition(
      x: mercator.x - _originMercator.x,
      y: mercator.y - _originMercator.y,
    );
  }
}