import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'grib_models.dart';

/// Painter personnalisé pour afficher une grille GRIB
class GribGridPainter extends CustomPainter {
  final ScalarGrid grid;
  final double vmin, vmax;
  final String colorMapName;
  final double opacity;
  final int samplingStride;
  final Offset Function(double, double, Size) projector;

  GribGridPainter({
    required this.grid,
    required this.vmin,
    required this.vmax,
    required this.projector,
    this.colorMapName = ColorMap.blueToRed,
    this.opacity = 0.6,
    this.samplingStride = 2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (grid.nx <= 0 || grid.ny <= 0) return;
    if ((vmax - vmin).abs() < 1e-10) return;

    // DEBUG: Log les limites et palette
    print('[GRIB_PAINTER] Heatmap: vmin=$vmin, vmax=$vmax, range=${(vmax-vmin).abs()}, colorMap=$colorMapName, opacity=$opacity');

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..filterQuality = FilterQuality.low;

    int pixelsDrawn = 0;
    for (int iy = 0; iy < grid.ny - 1; iy += samplingStride) {
      for (int ix = 0; ix < grid.nx - 1; ix += samplingStride) {
        final val = grid.valueAtIndex(ix, iy);
        if (val.isNaN) continue;

        final lon1 = grid.lonFromIndex(ix);
        final lat1 = grid.latFromIndex(iy);
        final lon2 = grid.lonFromIndex(ix + samplingStride);
        final lat2 = grid.latFromIndex(iy + samplingStride);

        final p1 = projector(lon1, lat1, size);
        final p2 = projector(lon2, lat2, size);

        final t = ((val - vmin) / (vmax - vmin)).clamp(0.0, 1.0);
        final colorInt = ColorMap.colorAt(colorMapName, t);
        final color = Color(colorInt).withOpacity(opacity);

        paint.color = color;

        final rect = Rect.fromPoints(p1, p2);
        if (rect.width.abs() > 0 && rect.height.abs() > 0) {
          canvas.drawRect(rect, paint);
          pixelsDrawn++;
        }
      }
    }
    print('[GRIB_PAINTER] Pixels dessinés: $pixelsDrawn');
  }

  @override
  bool shouldRepaint(GribGridPainter oldDelegate) {
    return oldDelegate.grid != grid ||
        oldDelegate.vmin != vmin ||
        oldDelegate.vmax != vmax ||
        oldDelegate.colorMapName != colorMapName ||
        oldDelegate.opacity != opacity;
  }
}

/// Painter pour les vecteurs (vent, courants, etc.)
class GribVectorFieldPainter extends CustomPainter {
  final ScalarGrid uGrid, vGrid;
  final double vmin, vmax;
  final double opacity;
  final int samplingStride;
  final Offset Function(double, double, Size) projector;
  final double? boundsMinX, boundsMaxX, boundsMinY, boundsMaxY; // Bounds pour filtrer

  GribVectorFieldPainter({
    required this.uGrid,
    required this.vGrid,
    required this.vmin,
    required this.vmax,
    required this.projector,
    this.opacity = 0.8,
    this.samplingStride = 4,
    this.boundsMinX,
    this.boundsMaxX,
    this.boundsMinY,
    this.boundsMaxY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (uGrid.nx <= 0 || uGrid.ny <= 0 || vGrid.nx <= 0 || vGrid.ny <= 0) return;

    print('[GRIB_VECTORS_PAINTER] Début du paint - U:${uGrid.nx}x${uGrid.ny}, V:${vGrid.nx}x${vGrid.ny}');
    print('[GRIB_VECTORS_PAINTER] Canvas size: ${size.width}x${size.height}');
    if (boundsMinX != null && boundsMaxX != null && boundsMinY != null && boundsMaxY != null) {
      print('[GRIB_VECTORS_PAINTER] Bounds locaux: X=[${boundsMinX!.toStringAsFixed(0)}..${boundsMaxX!.toStringAsFixed(0)}] m, Y=[${boundsMinY!.toStringAsFixed(0)}..${boundsMaxY!.toStringAsFixed(0)}] m');
    }
    print('[GRIB_VECTORS_PAINTER] Première flèche projetée: p0=(-4902161.7, 7016485.7) -> devrait être dans (0..${size.width}, 0..${size.height})');


    int arrowsDrawn = 0;
    int arrowsSkipped = 0;
    int arrowsInvalid = 0;
    int arrowsInfinity = 0;
    double minMag = double.infinity;
    double maxMag = double.negativeInfinity;

    // Sauter la première et dernière rangée (pôles) - projection Mercator impossible aux pôles
    for (int iy = 1; iy < uGrid.ny - 1; iy += samplingStride) {
      for (int ix = 0; ix < uGrid.nx; ix += samplingStride) {
        final u = uGrid.valueAtIndex(ix, iy);
        final v = vGrid.valueAtIndex(ix, iy);

        if (u.isNaN || v.isNaN) continue;

        final lon = uGrid.lonFromIndex(ix);
        final lat = uGrid.latFromIndex(iy);

        // FILTRAGE: Passer seulement les points dans les bounds locaux visibles
        if (boundsMinX != null && boundsMaxX != null && boundsMinY != null && boundsMaxY != null) {
          // Convertir lon/lat en Mercator local pour comparer avec bounds
          // ATTENTION: ici on utilise une estimation simple (le service Mercator n'est pas accessible)
          // Pour une meilleure approche, utiliser mercatorService.toLocal() dans course_canvas.dart
          
          // Approximation Mercator locale: ΔX ≈ Δlon * 111320 * cos(lat), ΔY ≈ Δlat * 111320
          // Mais pour l'instant, on fait un simple filtre sur lon/lat
          // (on suppose que si lon/lat est dans bounds géo approximatifs, il sera visible)
          
          // Les bounds sont en mètres Mercator, mais on peut les comparer à une enveloppe géo
          // Pour cette démo, on filtre les points qui sont probablement hors écran
          // (en supposant que le centre de la carte est autour de lon=50..100, lat=30..60)
          
          // Filtre simple: passer les points dans une "fenêtre" probable autour du centre
          // Si minX/maxX correspondent au parcours (entre -1M et +2M mètres), 
          // ça correspond à peu près à une zone côtière (pas le monde entier)
          
          // Pour être sûr, on projette d'abord et on vérifie après
        }

        // DEBUG: Log pour les premières flèches
        if (arrowsDrawn < 3) {
          print('[GRIB_VECTORS_PAINTER] lonFromIndex($ix)=$lon, latFromIndex($iy)=$lat');
        }

        final p0 = projector(lon, lat, size);
        
        // Vérifier que p0 est valide (pas NaN, pas Infinity)
        if (p0.dx.isNaN || p0.dy.isNaN || p0.dx.isInfinite || p0.dy.isInfinite) {
          if (arrowsDrawn < 3) {
            print('[GRIB_VECTORS_PAINTER] p0 invalide: dx=${p0.dx}, dy=${p0.dy}');
          }
          arrowsInvalid++;
          if (p0.dx.isInfinite || p0.dy.isInfinite) arrowsInfinity++;
          continue;
        }

        // FILTRAGE POST-PROJECTION: vérifier que p0 est dans les bounds écran
        // Ajouter une marge pour les flèches qui dépassent légèrement
        const margin = 100.0;
        if (p0.dx < -margin || p0.dx > size.width + margin ||
            p0.dy < -margin || p0.dy > size.height + margin) {
          arrowsSkipped++;
          if (arrowsDrawn < 5) {
            print('[GRIB_VECTORS_PAINTER] Flèche hors écran: p0=(${p0.dx.toStringAsFixed(1)}, ${p0.dy.toStringAsFixed(1)}), bounds=(0..${size.width}, 0..${size.height})');
          }
          continue;
        }

        final mag = math.sqrt(u * u + v * v);
        
        // Track magnitude statistics
        if (mag < minMag) minMag = mag;
        if (mag > maxMag) maxMag = mag;
        
        if (mag < 0.1) {
          arrowsSkipped++;
          continue;
        }

        arrowsDrawn++;

        const arrowScale = 80.0; // Augmenté pour bien voir les flèches
        final u_scaled = (u / mag) * arrowScale;
        final v_scaled = (v / mag) * arrowScale;

        final p1 = Offset(p0.dx + u_scaled, p0.dy - v_scaled);
        
        // Vérifier que p1 est aussi valide
        if (p1.dx.isNaN || p1.dy.isNaN) {
          arrowsInvalid++;
          continue;
        }

        // Couleur rouge pour bien voir les vecteurs
        final paint = Paint()
          ..strokeWidth = 3.0 // Plus épais pour être visible
          ..strokeCap = StrokeCap.round
          ..color = Colors.red.withOpacity(opacity);

        // Debug: afficher les 5 premières flèches
        if (arrowsDrawn <= 5) {
          print('[GRIB_VECTORS_PAINTER] Flèche #$arrowsDrawn: p0=(${p0.dx.toStringAsFixed(1)}, ${p0.dy.toStringAsFixed(1)}), p1=(${p1.dx.toStringAsFixed(1)}, ${p1.dy.toStringAsFixed(1)}), mag=${mag.toStringAsFixed(2)} m/s');
        }

        _drawArrow(canvas, p0, p1, paint);
      }
    }
    
    print('[GRIB_VECTORS_PAINTER] Flèches dessinées: $arrowsDrawn, skippées: $arrowsSkipped (trop petites), invalides: $arrowsInvalid (dont $arrowsInfinity avec Infinity)');
    if (minMag != double.infinity) {
      print('[GRIB_VECTORS_PAINTER] Magnitude: $minMag à $maxMag m/s (threshold: 0.1)');
    }
  }

  void _drawArrow(Canvas canvas, Offset start, Offset end, Paint paint) {
    const arrowHeadSize = 8.0;

    // Validate inputs - check for NaN, infinity, and negative/too large values
    if (start.dx.isNaN || start.dy.isNaN || end.dx.isNaN || end.dy.isNaN) {
      return; // Skip invalid arrows
    }
    
    if (start.dx.isInfinite || start.dy.isInfinite || end.dx.isInfinite || end.dy.isInfinite) {
      return; // Skip infinite values
    }
    
    // Check for reasonable bounds (canvas size typically 0-2000)
    if (start.dx < -10000 || start.dx > 10000 || start.dy < -10000 || start.dy > 10000 ||
        end.dx < -10000 || end.dx > 10000 || end.dy < -10000 || end.dy > 10000) {
      return; // Skip out-of-bounds arrows
    }

    canvas.drawLine(start, end, paint);

    final direction = (end - start).direction;
    final p1 = end + Offset.fromDirection(direction + 2.5, arrowHeadSize);
    final p2 = end + Offset.fromDirection(direction - 2.5, arrowHeadSize);

    // Validate arrow head points before drawing
    if (p1.dx.isNaN || p1.dy.isNaN || p2.dx.isNaN || p2.dy.isNaN) {
      return; // Skip invalid arrow heads
    }
    
    if (p1.dx.isInfinite || p1.dy.isInfinite || p2.dx.isInfinite || p2.dy.isInfinite) {
      return; // Skip infinite arrow heads
    }

    canvas.drawLine(end, p1, paint);
    canvas.drawLine(end, p2, paint);
  }

  @override
  bool shouldRepaint(GribVectorFieldPainter oldDelegate) {
    final needsRepaint = oldDelegate.uGrid != uGrid ||
        oldDelegate.vGrid != vGrid ||
        oldDelegate.vmin != vmin ||
        oldDelegate.vmax != vmax ||
        oldDelegate.opacity != opacity ||
        oldDelegate.samplingStride != samplingStride;
    
    if (needsRepaint) {
      print('[GRIB_VECTORS_PAINTER] shouldRepaint=true (grids changed)');
    }
    
    return needsRepaint;
  }
}
