import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'viewport_wind_grid.dart';
import 'package:kornog/features/charts/domain/models/geographic_position.dart';

/// Painter qui dessine 10 flèches basées sur les points du viewport
class ViewportWindArrowsPainter extends CustomPainter {
  final List<WindPoint> windPoints;
  final Map<GeographicPosition, Offset> positionToPixel; // position géo → pixel
  final double arrowLength;
  final Color arrowColor;
  
  ViewportWindArrowsPainter({
    required this.windPoints,
    required this.positionToPixel,
    this.arrowLength = 80.0,
    this.arrowColor = Colors.white,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (windPoints.isEmpty) {
      print('[WIND_ARROWS] No wind points to paint');
      return;
    }
    
    print('[WIND_ARROWS] Painting ${windPoints.length} arrows, positionToPixel size=${positionToPixel.length}');
    
    // Paint pour les flèches (sera modifié selon la vitesse)
    final arrowBasePaint = Paint()
      ..color = arrowColor
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    int drawn = 0;
    int offscreen = 0;
    int noWind = 0;
    
    for (final windPoint in windPoints) {
      // Récupérer la position pixel
      final pixelPos = positionToPixel[windPoint.position];
      if (pixelPos == null) {
        offscreen++;
        continue;
      }

      // Vérifier qu'on est dans le canvas
      if (pixelPos.dx < -100 || pixelPos.dx > size.width + 100 ||
          pixelPos.dy < -100 || pixelPos.dy > size.height + 100) {
        offscreen++;
        continue;
      }

      // Vérifier qu'on a du vent
      if (windPoint.wind == null || windPoint.windSpeed < 0.1) {
        noWind++;
        // Dessiner un petit point gris pour indiquer "pas de données"
        canvas.drawCircle(pixelPos, 3.0, Paint()..color = Colors.grey.withOpacity(0.5));
        continue;
      }

      // Calculer la longueur de la flèche proportionnelle à la vitesse
      // Normaliser: 0-20 m/s → 0-arrowLength pixels
      final windLength = (windPoint.windSpeed / 20.0 * arrowLength).clamp(5.0, arrowLength);

      // Épaisseur de la ligne variable selon la vitesse (0.5 à 3.5 points)
      final lineWidth = (windPoint.windSpeed / 20.0 * 3.0).clamp(0.5, 3.5);
      
      final arrowPaint = Paint()
        ..color = arrowColor
        ..strokeWidth = lineWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      // Calculer le vecteur de la flèche (direction du vent)
      final directionRad = windPoint.windDirection * math.pi / 180.0;
      final endX = pixelPos.dx + windLength * math.sin(directionRad);
      final endY = pixelPos.dy - windLength * math.cos(directionRad); // -Y car écran (Y vers le bas)

      final endPoint = Offset(endX, endY);

      // Dessiner la ligne principale
      canvas.drawLine(pixelPos, endPoint, arrowPaint);

      // Dessiner la pointe de flèche (V pointant dans la direction du vent)
      _drawArrowHead(canvas, pixelPos, endPoint, arrowPaint, windPoint.windSpeed);

      drawn++;
    }

    print('[WIND_ARROWS] Drawn=$drawn, Offscreen=$offscreen, NoWind=$noWind');
  }

  /// Dessine une pointe de flèche (V) au point final, avec taille variable selon la vitesse
  void _drawArrowHead(Canvas canvas, Offset start, Offset end, Paint paint, double windSpeed) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final angle = math.atan2(dy, dx);
    
    // Taille de la pointe variable selon la vitesse du vent (0-20 m/s), divisée par 2
    final arrowHeadSize = (windSpeed / 20.0 * 10.0).clamp(4.0, 10.0);
    const arrowHeadAngle = math.pi / 6; // 30 degrés

    // Deux points de la pointe du V
    final left = Offset(
      end.dx - arrowHeadSize * math.cos(angle - arrowHeadAngle),
      end.dy - arrowHeadSize * math.sin(angle - arrowHeadAngle),
    );
    
    final right = Offset(
      end.dx - arrowHeadSize * math.cos(angle + arrowHeadAngle),
      end.dy - arrowHeadSize * math.sin(angle + arrowHeadAngle),
    );

    // Dessiner le V
    canvas.drawLine(end, left, paint);
    canvas.drawLine(end, right, paint);
  }

  @override
  bool shouldRepaint(ViewportWindArrowsPainter oldDelegate) {
    return oldDelegate.windPoints.length != windPoints.length ||
        oldDelegate.arrowColor != arrowColor ||
        oldDelegate.arrowLength != arrowLength;
  }
}
