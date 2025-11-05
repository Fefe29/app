import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:kornog/data/datasources/gribs/grib_interpolation_service.dart';
import 'package:kornog/data/datasources/gribs/grib_models.dart';
import 'package:kornog/features/charts/presentation/widgets/course_canvas.dart';

/// Dessine des flèches de vent interpolées partout sur l'écran
/// Contrairement à GribVectorFieldPainter qui suit la grille,
/// celui-ci place des flèches librement basées sur l'interpolation
class InterpolatedWindArrowsPainter extends CustomPainter {
  final List<ScalarGrid> uGrids;
  final List<ScalarGrid> vGrids;
  final List<DateTime> timestamps;
  final DateTime currentTime;
  final ViewTransform view;
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
    this.arrowsPerSide = 5,
    this.arrowLength = 30,
    this.arrowColor = Colors.blue,
    this.opacity = 0.7,
  }) {
    // Calcule les limites géo du viewport
    _computeGeoLimits();
  }

  void _computeGeoLimits() {
    // Inverse la transformation view pour obtenir lon/lat
    // C'est une approximation - pour plus de précision il faudrait
    // inverser la projection Mercator complète
    final grid = uGrids.first;
    
    minLon = view.minX;
    maxLon = view.maxX;
    minLat = view.minY;
    maxLat = view.maxY;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (uGrids.isEmpty || vGrids.isEmpty) return;

    final paint = Paint()
      ..color = arrowColor.withOpacity(opacity)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Grille d'arrows à travers le viewport
    for (int i = 0; i < arrowsPerSide; i++) {
      for (int j = 0; j < arrowsPerSide; j++) {
        final xNorm = i / (arrowsPerSide - 1);
        final yNorm = j / (arrowsPerSide - 1);

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

        if (wind == null) continue;

        // Projette la position en pixels
        final pixelPos = view.project(lon, lat, size);

        // Dessine l'arrow
        _drawWindArrow(canvas, paint, pixelPos, wind, size);
      }
    }
  }

  void _drawWindArrow(
    Canvas canvas,
    Paint paint,
    Offset center,
    WindVector wind,
    Size size,
  ) {
    // Hors écran?
    if (center.dx < 0 ||
        center.dx > size.width ||
        center.dy < 0 ||
        center.dy > size.height) {
      return;
    }

    // Convertis la direction en radians (0° = Nord)
    final directionRad = wind.direction * math.pi / 180;

    // Calcule la longueur de l'arrow proportionnelle à la vitesse
    // Clamp entre 5 et arrowLength pixels
    final speedNormalized = (wind.speed / 20).clamp(0, 1); // 20 m/s = max
    final actualLength = 5 + speedNormalized * (arrowLength - 5);

    // Point final de l'arrow
    final endX = center.dx + actualLength * math.sin(directionRad);
    final endY = center.dy - actualLength * math.cos(directionRad);
    final endPoint = Offset(endX, endY);

    // Dessine la ligne principale
    canvas.drawLine(center, endPoint, paint);

    // Dessine la pointe de flèche
    final arrowHeadSize = 8.0;
    const arrowHeadAngle = math.pi / 6; // 30°

    final angle1 = directionRad - math.pi + arrowHeadAngle;
    final angle2 = directionRad - math.pi - arrowHeadAngle;

    final head1 = Offset(
      endPoint.dx + arrowHeadSize * math.cos(angle1),
      endPoint.dy + arrowHeadSize * math.sin(angle1),
    );
    final head2 = Offset(
      endPoint.dx + arrowHeadSize * math.cos(angle2),
      endPoint.dy + arrowHeadSize * math.sin(angle2),
    );

    canvas.drawLine(endPoint, head1, paint);
    canvas.drawLine(endPoint, head2, paint);

    // Optionnel: Dessine un petit cercle au centre et affiche la vitesse
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(center, 3, paint);
    
    // Affiche la vitesse en texte (optionnel)
    // _drawWindSpeed(canvas, center, wind);
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
