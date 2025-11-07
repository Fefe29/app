import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'viewport_wind_grid.dart';
import 'package:kornog/features/charts/domain/models/geographic_position.dart';

/// Painter qui crée un gradient de couleur basé sur les 50 points du viewport
/// Les couleurs varient selon la vitesse du vent (0-20 m/s)
class ViewportWindHeatmapPainter extends CustomPainter {
  final List<WindPoint> windPoints;
  final Map<GeographicPosition, Offset> positionToPixel; // position géo → pixel
  final double gridSpacing; // pixels entre les points
  
  ViewportWindHeatmapPainter({
    required this.windPoints,
    required this.positionToPixel,
    this.gridSpacing = 100.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (windPoints.isEmpty) return;
    
    print('[HEATMAP] Painting heatmap with ${windPoints.length} points');
    
    // Créer une grille interpolée du heatmap basée sur les 50 points
    _paintInterpolatedHeatmap(canvas, size);
  }

  /// Crée un heatmap lissé par interpolation basée sur les 50 points
  /// Utilise une interpolation bilinéaire pour un gradient fluide
  void _paintInterpolatedHeatmap(Canvas canvas, Size size) {
    // Pour chaque pixel, interpoler la couleur basée sur les points proches
    final imageData = <List<Color>>[];
    
    const pixelStep = 10; // Calculer 1 pixel tous les 10 pixels réels (pour perf)
    
    for (int py = 0; py < size.height.toInt(); py += pixelStep) {
      final row = <Color>[];
      
      for (int px = 0; px < size.width.toInt(); px += pixelStep) {
        final pixelPos = Offset(px.toDouble(), py.toDouble());
        
        // Interpoler la vitesse du vent à ce pixel
        final windSpeed = _interpolateWindSpeed(pixelPos);
        
        // Convertir en couleur (0 m/s = blanc, 20 m/s = violet foncé)
        final color = _speedToColor(windSpeed);
        row.add(color);
      }
      
      imageData.add(row);
    }

    // Dessiner le heatmap
    for (int row = 0; row < imageData.length - 1; row++) {
      for (int col = 0; col < imageData[row].length - 1; col++) {
        final x = (col * pixelStep).toDouble();
        final y = (row * pixelStep).toDouble();
        
        // Créer un rectangle et le remplir avec la couleur
        final rect = Rect.fromLTWH(x, y, pixelStep.toDouble(), pixelStep.toDouble());
        canvas.drawRect(
          rect,
          Paint()..color = imageData[row][col],
        );
      }
    }
  }

  /// Interpole la vitesse du vent au pixel donné
  /// Utilise une interpolation IDW (Inverse Distance Weighting) sur les points proches
  double _interpolateWindSpeed(Offset pixelPos) {
    // Trouver les points les plus proches
    final distances = windPoints.map((p) {
      final pPos = positionToPixel[p.position];
      if (pPos == null) return (p, double.infinity);
      
      final dx = pixelPos.dx - pPos.dx;
      final dy = pixelPos.dy - pPos.dy;
      final dist = math.sqrt(dx * dx + dy * dy);
      
      return (p, dist);
    }).toList();

    // Trier par distance
    distances.sort((a, b) => a.$2.compareTo(b.$2));

    // Utiliser les 4 points les plus proches pour l'interpolation IDW
    const k = 4; // Nombre de points voisins
    double sumWeight = 0;
    double sumWeightedSpeed = 0;
    
    for (int i = 0; i < math.min(k, distances.length); i++) {
      final (point, dist) = distances[i];
      
      if (point.wind == null) continue;
      
      // Poids inversement proportionnel à la distance (+ epsilon pour éviter division par 0)
      const epsilon = 1.0;
      final weight = 1.0 / (dist + epsilon);
      
      sumWeight += weight;
      sumWeightedSpeed += weight * point.windSpeed;
    }

    return sumWeight > 0 ? sumWeightedSpeed / sumWeight : 0.0;
  }

  /// Convertit une vitesse de vent en couleur
  /// Utilise le même dégradé que la légende: blanc → bleu → vert → jaune → orange → rouge → violet
  Color _speedToColor(double windSpeed) {
    // Normaliser: 0-20 m/s → 0-1
    final normalized = (windSpeed / 20.0).clamp(0.0, 1.0);
    
    // Gradient identique à wind_speed_legend_bar: blanc→bleu→vert→jaune→rouge→violet
    const colors = [
      Color(0xFFFFFFFF),   // 0.0 - Blanc
      Color(0xFF6B9FD1),   // 0.12 - Bleu clair
      Color(0xFF1E7DB8),   // 0.25 - Bleu foncé
      Color(0xFF00AA00),   // 0.38 - Vert
      Color(0xFFFFFF00),   // 0.50 - Jaune
      Color(0xFFFFA500),   // 0.62 - Orange
      Color(0xFFFF0000),   // 0.75 - Rouge
      Color(0xFFB73FD8),   // 1.0 - Magenta/Violet
    ];
    
    const stops = [
      0.0,    // 0%
      0.12,   // 12%
      0.25,   // 25%
      0.38,   // 38%
      0.50,   // 50%
      0.62,   // 62%
      0.75,   // 75%
      1.0,    // 100%
    ];

    // Trouver les deux couleurs à interpoler
    int i0 = 0, i1 = 0;
    for (int i = 0; i < stops.length - 1; i++) {
      if (normalized >= stops[i] && normalized <= stops[i + 1]) {
        i0 = i;
        i1 = i + 1;
        break;
      }
    }

    final c0 = colors[i0];
    final c1 = colors[i1];
    
    // Facteur d'interpolation entre les deux couleurs
    final t = (normalized - stops[i0]) / (stops[i1] - stops[i0]);

    // Interpoler chaque composante
    return Color.fromARGB(
      255,
      (_lerp(c0.red.toDouble(), c1.red.toDouble(), t)).toInt(),
      (_lerp(c0.green.toDouble(), c1.green.toDouble(), t)).toInt(),
      (_lerp(c0.blue.toDouble(), c1.blue.toDouble(), t)).toInt(),
    );
  }

  double _lerp(double a, double b, double t) => a * (1 - t) + b * t;

  @override
  bool shouldRepaint(ViewportWindHeatmapPainter oldDelegate) {
    return oldDelegate.windPoints.length != windPoints.length ||
        oldDelegate.gridSpacing != gridSpacing;
  }
}
