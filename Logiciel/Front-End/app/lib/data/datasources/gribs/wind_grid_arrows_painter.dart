import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:kornog/data/datasources/gribs/grib_interpolation_service.dart';
import 'package:kornog/features/charts/domain/models/geographic_position.dart';

/// Représente un point avec sa position et son vent
class GridArrowPoint {
  final GeographicPosition position;
  final Offset pixelPosition;
  final WindVector? wind;
  
  GridArrowPoint({
    required this.position,
    required this.pixelPosition,
    this.wind,
  });
  
  double get windSpeed => wind?.speed ?? 0.0;
  double get windDirection => wind?.direction ?? 0.0;
  bool get hasWind => wind != null && windSpeed > 0.1;
}

/// Painter qui dessine 10 flèches de vent uniformément réparties sur l'écran
class WindGridArrowsPainter extends CustomPainter {
  final List<GridArrowPoint> arrows;
  final double arrowLength;
  final Color arrowColor;
  final double strokeWidth;
  
  WindGridArrowsPainter({
    required this.arrows,
    this.arrowLength = 60.0,
    this.arrowColor = Colors.white,
    this.strokeWidth = 2.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (arrows.isEmpty) {
      print('[WIND_GRID_ARROWS] No arrows to paint');
      return;
    }
    
    final arrowPaint = Paint()
      ..color = arrowColor
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    int drawn = 0;
    int noWind = 0;
    
    for (final arrow in arrows) {
      // Vérifier qu'on a du vent
      if (!arrow.hasWind) {
        // Petit cercle gris pour "pas de données"
        canvas.drawCircle(arrow.pixelPosition, 4.0, 
          Paint()..color = Colors.grey.withOpacity(0.3));
        noWind++;
        continue;
      }

      // Calculer la longueur proportionnelle à la vitesse
      // Normaliser: 0-20 m/s → 0-arrowLength pixels
      final windLength = (arrow.windSpeed / 20.0 * arrowLength).clamp(8.0, arrowLength);

      // Calculer le vecteur de la flèche
      final directionRad = arrow.windDirection * math.pi / 180.0;
      final endX = arrow.pixelPosition.dx + windLength * math.sin(directionRad);
      final endY = arrow.pixelPosition.dy - windLength * math.cos(directionRad);
      final endPoint = Offset(endX, endY);

      // Dessiner la ligne principale
      canvas.drawLine(arrow.pixelPosition, endPoint, arrowPaint);

      // Dessiner la pointe de flèche
      _drawArrowHead(canvas, arrow.pixelPosition, endPoint, arrowPaint, windLength);

      // Optionnel: petit cercle à la base de la flèche
      canvas.drawCircle(arrow.pixelPosition, 3.0, arrowPaint);

      drawn++;
    }

    print('[WIND_GRID_ARROWS] Drawn=$drawn arrows, NoWind=$noWind');
  }

  /// Dessine une pointe de flèche triangulaire
  void _drawArrowHead(Canvas canvas, Offset start, Offset end, Paint paint, double arrowLen) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final angle = math.atan2(dy, dx);
    
    const arrowHeadSize = 12.0;
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

    // Dessiner le triangle de la pointe
    canvas.drawLine(end, left, paint);
    canvas.drawLine(end, right, paint);
    
    // Optionnel: remplir le triangle pour plus de visibilité
    final path = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
    
    canvas.drawPath(path, Paint()
      ..color = paint.color.withOpacity(0.2)
      ..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(WindGridArrowsPainter oldDelegate) {
    return oldDelegate.arrows.length != arrows.length ||
        oldDelegate.arrowColor != arrowColor ||
        oldDelegate.arrowLength != arrowLength;
  }
}
