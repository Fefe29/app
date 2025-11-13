import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:kornog/data/datasources/gribs/grib_interpolation_service.dart';
import 'package:kornog/data/datasources/gribs/grib_models.dart';
import 'package:kornog/features/charts/presentation/models/view_transform.dart';
import 'package:kornog/features/charts/providers/mercator_coordinate_system_provider.dart';
import 'package:kornog/features/charts/domain/models/geographic_position.dart';

/// Dessine des flèches de vent interpolées partout sur l'écran
/// Contrairement à GribVectorFieldPainter qui suit la grille,
/// celui-ci place des flèches librement basées sur l'interpolation
class InterpolatedWindArrowsPainter extends CustomPainter {
  final List<ScalarGrid> uGrids;
  final List<ScalarGrid> vGrids;
  final List<DateTime> timestamps;
  final DateTime currentTime;
  final ViewTransform view;
  final MercatorCoordinateSystemService mercatorService;
  final int arrowsPerSide;
  final double arrowLength;
  final Color arrowColor;
  final double opacity;
  
  // Coordonnées géographiques du viewport
  late final double minLon;
  late final double maxLon;
  late final double minLat;
  late final double maxLat;

  InterpolatedWindArrowsPainter({
    required this.uGrids,
    required this.vGrids,
    required this.timestamps,
    required this.currentTime,
    required this.view,
    required this.mercatorService,
    this.arrowsPerSide = 5,
    this.arrowLength = 30,
    this.arrowColor = Colors.blue,
    this.opacity = 0.7,
  }) {
    // Calcule les limites géo du viewport
    _computeGeoLimits();
  }

  void _computeGeoLimits() {
    // Convertit les limites du ViewTransform (coordonnées locales Mercator)
    // vers les coordonnées géographiques (lon/lat)
    final localMinCorner = LocalPosition(x: view.minX, y: view.minY);
    final localMaxCorner = LocalPosition(x: view.maxX, y: view.maxY);
    
    final geoMin = mercatorService.toGeographic(localMinCorner);
    final geoMax = mercatorService.toGeographic(localMaxCorner);
    
    minLon = geoMin.longitude;
    maxLon = geoMax.longitude;
    minLat = geoMin.latitude;
    maxLat = geoMax.latitude;
    
    print('[ARROWS_GEO_LIMITS] Viewport local: (${view.minX}, ${view.minY}) .. (${view.maxX}, ${view.maxY})');
    print('[ARROWS_GEO_LIMITS] Converted to geo: lon($minLon..$maxLon), lat($minLat..$maxLat)');
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (uGrids.isEmpty || vGrids.isEmpty) return;

    final paint = Paint()
      ..color = arrowColor.withOpacity(opacity)
      ..strokeWidth = 2.5  // Augmenté pour meilleure visibilité
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    print('[ARROWS_PAINTER] ═══════════════════════════════════════');
    print('[ARROWS_PAINTER] 🎯 PAINT APPELÉ - Grille ${arrowsPerSide}x${arrowsPerSide}');
    print('[ARROWS_PAINTER] View bounds: minLon=$minLon, maxLon=$maxLon, minLat=$minLat, maxLat=$maxLat');
    print('[ARROWS_PAINTER] Canvas size: $size, arrowLength: $arrowLength');

    int arrowsDrawn = 0;
    int arrowsNull = 0;
    int arrowsOffscreen = 0;

    // Grille d'arrows à travers le viewport
    final divisor = math.max(1, arrowsPerSide - 1); // Prevent division by zero
    for (int i = 0; i < arrowsPerSide; i++) {
      for (int j = 0; j < arrowsPerSide; j++) {
        final xNorm = divisor > 0 ? i / divisor : 0.5;
        final yNorm = divisor > 0 ? j / divisor : 0.5;

        final lon = minLon + xNorm * (maxLon - minLon);
        final lat = minLat + yNorm * (maxLat - minLat);

        // Interpole le vent à cette position
        final wind = GribInterpolationService.interpolateWind(
          uGrids,
          vGrids,
          timestamps,
          lon,
          lat,
          currentTime,
        );

        if (wind == null) {
          arrowsNull++;
          continue;
        }

        // Projette la position en pixels
        // IMPORTANT: d'abord convertir géographique -> local, puis local -> pixels
        final geoPos = GeographicPosition(latitude: lat, longitude: lon);
        final localPos = mercatorService.toLocal(geoPos);
        final pixelPos = view.project(localPos.x, localPos.y, size);

        // Check if offscreen
        if (pixelPos.dx < 0 ||
            pixelPos.dx > size.width ||
            pixelPos.dy < 0 ||
            pixelPos.dy > size.height) {
          arrowsOffscreen++;
          if (arrowsOffscreen <= 5) {
            print('[ARROWS_PAINTER] ⚠️  Arrow ($i,$j) offscreen: pixelPos=$pixelPos, canvasSize=$size');
          }
          continue;
        }

        if (arrowsDrawn < 3) {
          print('[ARROWS_PAINTER] ✅ Arrow ($i,$j): lon=$lon, lat=$lat, pixelPos=$pixelPos, wind=${wind.speed.toStringAsFixed(1)}m/s dir=${wind.direction.toStringAsFixed(0)}°');
        }

        // Dessine l'arrow
        _drawWindArrow(canvas, paint, pixelPos, wind, size);
        arrowsDrawn++;
      }
    }
    print('[ARROWS_PAINTER] RÉSUMÉ: Drawn=$arrowsDrawn, Null=$arrowsNull, Offscreen=$arrowsOffscreen (total attemps=${arrowsPerSide*arrowsPerSide})');
    print('[ARROWS_PAINTER] ═══════════════════════════════════════');
  }

  void _drawWindArrow(
    Canvas canvas,
    Paint paint,
    Offset center,
    WindVector wind,
    Size size,
  ) {
    // Convertis la direction en radians (0° = Nord)
    final directionRad = wind.direction * math.pi / 180;

    // Calcule la longueur de l'arrow proportionnelle à la vitesse
    // Clamp entre 10% et 100% de arrowLength
    final speedNormalized = (wind.speed / 25).clamp(0, 1); // 25 m/s = max
    final actualLength = arrowLength * (0.1 + speedNormalized * 0.9); // Entre 10% et 100%

    // Point final de l'arrow
    final endX = center.dx + actualLength * math.sin(directionRad);
    final endY = center.dy - actualLength * math.cos(directionRad);
    final endPoint = Offset(endX, endY);

    // === Dessine la tige (ligne principale) ===
    paint.style = PaintingStyle.stroke;
    paint.strokeCap = StrokeCap.round;
    canvas.drawLine(center, endPoint, paint);

    // === Simple arrowhead: juste deux petites lignes en V ===
    final arrowHeadSize = actualLength * 0.25; // Taille de la pointe
    
    // Deux points formant un V à l'extrémité de la flèche
    // Angles à 30° de chaque côté de la direction principale
    final angle1 = directionRad + math.pi / 6;  // +30° par rapport à la direction inverse
    final angle2 = directionRad - math.pi / 6;  // -30° par rapport à la direction inverse
    
    final point1 = Offset(
      endPoint.dx - arrowHeadSize * math.sin(angle1),
      endPoint.dy + arrowHeadSize * math.cos(angle1),
    );
    final point2 = Offset(
      endPoint.dx - arrowHeadSize * math.sin(angle2),
      endPoint.dy + arrowHeadSize * math.cos(angle2),
    );

    // Dessine les deux lignes du V
    canvas.drawLine(endPoint, point1, paint);
    canvas.drawLine(endPoint, point2, paint);

    // === Cercle central ===
    final centerCirclePaint = Paint()
      ..color = arrowColor.withOpacity(opacity)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 3, centerCirclePaint);

    // Contour du cercle
    final centerCircleStroke = Paint()
      ..color = arrowColor.withOpacity(opacity * 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, 3, centerCircleStroke);
  }

  @override
  bool shouldRepaint(covariant InterpolatedWindArrowsPainter oldDelegate) {
    return oldDelegate.currentTime != currentTime ||
        oldDelegate.uGrids.hashCode != uGrids.hashCode ||
        oldDelegate.vGrids.hashCode != vGrids.hashCode ||
        oldDelegate.view != view ||
        oldDelegate.arrowsPerSide != arrowsPerSide;
  }
}

/// Version optimisée qui cache et ne redessine que si nécessaire
class CachedInterpolatedWindArrowsPainter extends CustomPainter {
  final List<ScalarGrid> uGrids;
  final List<ScalarGrid> vGrids;
  final List<DateTime> timestamps;
  final DateTime currentTime;
  final ViewTransform view;
  final MercatorCoordinateSystemService mercatorService;
  final int arrowsPerSide;
  final double arrowLength;
  final Color arrowColor;
  final double opacity;

  CachedInterpolatedWindArrowsPainter({
    required this.uGrids,
    required this.vGrids,
    required this.timestamps,
    required this.currentTime,
    required this.view,
    required this.mercatorService,
    this.arrowsPerSide = 5,
    this.arrowLength = 30,
    this.arrowColor = Colors.blue,
    this.opacity = 0.7,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Délègue au painter normal
    final painter = InterpolatedWindArrowsPainter(
      uGrids: uGrids,
      vGrids: vGrids,
      timestamps: timestamps,
      currentTime: currentTime,
      view: view,
      mercatorService: mercatorService,
      arrowsPerSide: arrowsPerSide,
      arrowLength: arrowLength,
      arrowColor: arrowColor,
      opacity: opacity,
    );
    painter.paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant CachedInterpolatedWindArrowsPainter oldDelegate) {
    return oldDelegate.currentTime != currentTime ||
        oldDelegate.uGrids.hashCode != uGrids.hashCode ||
        oldDelegate.vGrids.hashCode != vGrids.hashCode;
  }
}
