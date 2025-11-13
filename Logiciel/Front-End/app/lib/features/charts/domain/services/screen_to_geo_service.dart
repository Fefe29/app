import 'package:kornog/features/charts/presentation/models/view_transform.dart';
import 'package:kornog/features/charts/domain/models/geographic_position.dart';
import 'package:flutter/material.dart';

/// Service pour convertir les coordonnées écran ↔ géographiques
class ScreenToGeoService {
  /// Convertit un point pixel en coordonnées géographiques (lon, lat)
  /// 
  /// [pixelPos] - Position en pixels sur l'écran (Offset)
  /// [view] - ViewTransform actuelle (contient la projection)
  /// [canvasSize] - Taille du canvas
  /// 
  /// Retourne (lon, lat) ou null si hors de la grille
  static GeographicPosition? pixelToGeo(
    Offset pixelPos,
    ViewTransform view,
    Size canvasSize,
  ) {
    // Inverse de: view.project(x, y, size)
    // view.project retourne:
    //   px = offsetX + (x - minX) * scale
    //   py = size.height - offsetY - (y - minY) * scale
    //
    // Inversion:
    //   x = minX + (px - offsetX) / scale
    //   y = minY + (size.height - py - offsetY) / scale

    final dx = (pixelPos.dx - view.offsetX) / view.scale;
    final dy = (canvasSize.height - pixelPos.dy - view.offsetY) / view.scale;

    final x = view.minX + dx;
    final y = view.minY + dy;

    // Vérifie que c'est dans les limites
    if (x < view.minX || x > view.maxX || y < view.minY || y > view.maxY) {
      return null;
    }

    return GeographicPosition(latitude: y, longitude: x);
  }

  /// Convertit des coordonnées géographiques en pixels écran
  /// C'est juste un wrapper de view.project
  static Offset geoToPixel(
    GeographicPosition geo,
    ViewTransform view,
    Size canvasSize,
  ) {
    return view.project(geo.longitude, geo.latitude, canvasSize);
  }

  /// Obtient le vent interpolé à une position pixel
  static Future<(double?, double?, double?, double?)> getWindAtPixel(
    Offset pixelPos,
    ViewTransform view,
    Size canvasSize,
    // Fonction pour interpoler le vent
    Future<(double, double, double, double)?> Function(double, double, DateTime)
        windInterpolator,
  ) async {
    final geo = pixelToGeo(pixelPos, view, canvasSize);
    if (geo == null) return (null, null, null, null);

    final wind = await windInterpolator(geo.longitude, geo.latitude, DateTime.now());
    return wind;
  }
}

/// Extension pour faciliter la conversion sur Offset
extension OffsetToGeo on Offset {
  /// Convertit ce point écran en géographique
  GeographicPosition? toGeo(ViewTransform view, Size canvasSize) {
    return ScreenToGeoService.pixelToGeo(this, view, canvasSize);
  }
}

/// Extension pour faciliter la conversion sur GeographicPosition
extension GeoToOffset on GeographicPosition {
  /// Convertit cette position géographique en pixels écran
  Offset toPixel(ViewTransform view, Size canvasSize) {
    return ScreenToGeoService.geoToPixel(this, view, canvasSize);
  }
}
