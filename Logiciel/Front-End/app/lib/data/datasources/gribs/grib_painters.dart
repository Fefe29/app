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
  final int? targetVectorCount; // Nouveau: nombre de vecteurs cible (remplace samplingStride si non-null)

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
    this.targetVectorCount, // 20 pour avoir ~20 vecteurs, null pour utiliser samplingStride
  });

  @override
  void paint(Canvas canvas, Size size) {
    // DEBUG: Log les grilles reçues
    print('[GRIB_VECTORS_PAINTER] 🎨 PAINT CALLED: uGrid=${uGrid.nx}x${uGrid.ny}, vGrid=${vGrid.nx}x${vGrid.ny}, size=$size');
    
    if (uGrid.nx <= 0 || uGrid.ny <= 0 || vGrid.nx <= 0 || vGrid.ny <= 0) {
      print('[GRIB_VECTORS_PAINTER] ❌ Grille vide, abandon');
      return;
    }

    print('[GRIB_VECTORS_PAINTER] 🎯 PAINT APPELÉ');
    print('[GRIB_VECTORS_PAINTER] Mode: ${targetVectorCount != null ? 'INTERPOLÉ (cible=$targetVectorCount)' : 'LEGACY (stride=$samplingStride)'}');
    print('[GRIB_VECTORS_PAINTER] Grilles: U=${uGrid.nx}x${uGrid.ny}, V=${vGrid.nx}x${vGrid.ny}');
    print('[GRIB_VECTORS_PAINTER] Canvas: ${size.width}x${size.height}');
    print('[GRIB_VECTORS_PAINTER] Bounds: X=[${boundsMinX?.toStringAsFixed(2) ?? "null"}, ${boundsMaxX?.toStringAsFixed(2) ?? "null"}], Y=[${boundsMinY?.toStringAsFixed(2) ?? "null"}, ${boundsMaxY?.toStringAsFixed(2) ?? "null"}]');
    print('[GRIB_VECTORS_PAINTER] Lon/Lat: lon0=${uGrid.lon0}, lat0=${uGrid.lat0}, dlon=${uGrid.dlon}, dlat=${uGrid.dlat}');

    int arrowsDrawn = 0;
    int arrowsSkipped = 0;
    int arrowsInvalid = 0;
    double minMag = double.infinity;
    double maxMag = double.negativeInfinity;

    // NOUVELLE APPROCHE: utiliser des points interpolés si targetVectorCount est défini
    if (targetVectorCount != null && targetVectorCount! > 0) {
      print('[GRIB_VECTORS_PAINTER] 📌 Mode INTERPOLÉ: génération de ${targetVectorCount} points...');
      
      // Générer une grille régulière de points interpolés
      final gridPoints = uGrid.generateInterpolatedGridPoints(
        targetVectorCount: targetVectorCount!,
      );

      print('[GRIB_VECTORS_PAINTER] Points interpolés générés: ${gridPoints.length}');

      for (final (lon, lat) in gridPoints) {
        // Interpoler U et V à ce point
        final u = uGrid.sampleAtLatLon(lat, lon);
        final v = vGrid.sampleAtLatLon(lat, lon);

        if (u.isNaN || v.isNaN) {
          arrowsSkipped++;
          continue;
        }

        final p0 = projector(lon, lat, size);

        // Vérifier validité
        if (p0.dx.isNaN || p0.dy.isNaN || p0.dx.isInfinite || p0.dy.isInfinite) {
          arrowsInvalid++;
          continue;
        }

        // Filtrage post-projection
        const margin = 100.0;
        if (p0.dx < -margin || p0.dx > size.width + margin ||
            p0.dy < -margin || p0.dy > size.height + margin) {
          arrowsSkipped++;
          continue;
        }

        final mag = math.sqrt(u * u + v * v);

        if (mag < minMag) minMag = mag;
        if (mag > maxMag) maxMag = mag;

        if (mag < 0.1) {
          arrowsSkipped++;
          continue;
        }

        arrowsDrawn++;

        const arrowScale = 80.0;
        final uScaled = (u / mag) * arrowScale;
        final vScaled = (v / mag) * arrowScale;

        final p1 = Offset(p0.dx + uScaled, p0.dy - vScaled);

        if (p1.dx.isNaN || p1.dy.isNaN) {
          arrowsInvalid++;
          continue;
        }

        final paint = Paint()
          ..strokeWidth = 6.0 // TRÈS ÉPAIS pour être visible
          ..strokeCap = StrokeCap.round
          ..color = Colors.cyan; // CYAN opaque, très visible sur vert

        _drawArrow(canvas, p0, p1, paint);
      }
    } else {
      print('[GRIB_VECTORS_PAINTER] 📌 Mode GRILLE GFS FILTRÉE: affichage des flèches visibles');
      
      // Adapter le stride pour avoir ~targetVectorCount flèches au total
      // (la plupart seront filtrées hors-bounds)
      final totalPoints = uGrid.nx * uGrid.ny;
      final adaptiveStride = math.max(1, (math.sqrt(totalPoints / (targetVectorCount! * 2 + 1))).ceil());
      
      print('[GRIB_VECTORS_PAINTER] 🎯 Grille ${uGrid.nx}x${uGrid.ny}, stride=$adaptiveStride, cible ~${targetVectorCount} visibles');
      print('[GRIB_VECTORS_PAINTER] Bounds écran: X=[${boundsMinX}, ${boundsMaxX}], Y=[${boundsMinY}, ${boundsMaxY}]');
      
      double minMagVisibles = double.infinity;
      double maxMagVisibles = double.negativeInfinity;
      int pointsInBounds = 0;
      int pointsOutOfBounds = 0;
      
      // Parcourir la grille GFS avec stride
      for (int iy = 0; iy < uGrid.ny; iy += adaptiveStride) {
        for (int ix = 0; ix < uGrid.nx; ix += adaptiveStride) {
          final u = uGrid.valueAtIndex(ix, iy);
          final v = vGrid.valueAtIndex(ix, iy);

          if (u.isNaN || v.isNaN) continue;

          final lon = uGrid.lonFromIndex(ix);
          final lat = uGrid.latFromIndex(iy);
          
          // Projeter le point
          final p0 = projector(lon, lat, size);
          
          if (p0.dx.isNaN || p0.dy.isNaN || p0.dx.isInfinite || p0.dy.isInfinite) continue;
          
          // FILTRER PAR BOUNDS: ne garder que les flèches visibles
          final inBoundsX = boundsMinX != null && boundsMaxX != null 
            ? (p0.dx >= boundsMinX! && p0.dx <= boundsMaxX!)
            : true;
          final inBoundsY = boundsMinY != null && boundsMaxY != null 
            ? (p0.dy >= boundsMinY! && p0.dy <= boundsMaxY!)
            : true;
            
          if (!inBoundsX || !inBoundsY) {
            pointsOutOfBounds++;
            continue;
          }
          
          pointsInBounds++;
          
          final mag = math.sqrt(u * u + v * v);
          
          // Ignorer les vents très faibles
          if (mag < 0.3) {
            arrowsSkipped++;
            continue;
          }
          
          if (mag < minMagVisibles) minMagVisibles = mag;
          if (mag > maxMagVisibles) maxMagVisibles = mag;

          arrowsDrawn++;
          
          // Dessiner la flèche
          const arrowScale = 20.0;
          final uScaled = (u / mag) * arrowScale;
          final vScaled = (v / mag) * arrowScale;
          
          final p1 = Offset(p0.dx + uScaled, p0.dy - vScaled);

          final paint = Paint()
            ..strokeWidth = 1.5
            ..strokeCap = StrokeCap.round
            ..color = Colors.cyan;
          
          _drawArrow(canvas, p0, p1, paint);
        }
      }
      
      if (minMagVisibles.isInfinite) {
        print('[GRIB_VECTORS_PAINTER] ⚠️  AUCUNE FLÈCHE trouvée: ${pointsOutOfBounds} hors bounds, ${pointsInBounds} in bounds');
      } else {
        print('[GRIB_VECTORS_PAINTER] ✅ ${arrowsDrawn} flèches dessinées, ${pointsInBounds} points in bounds, mag [$minMagVisibles, $maxMagVisibles]');
      }
    }

    print('[GRIB_VECTORS_PAINTER] ✅ RÉSULTAT: $arrowsDrawn dessinées, $arrowsSkipped skippées, $arrowsInvalid invalides');
    if (minMag != double.infinity) {
      print('[GRIB_VECTORS_PAINTER] Magnitude: $minMag à $maxMag m/s');
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
        oldDelegate.samplingStride != samplingStride ||
        oldDelegate.targetVectorCount != targetVectorCount;
    
    if (needsRepaint) {
      print('[GRIB_VECTORS_PAINTER] shouldRepaint=true');
    }
    
    return needsRepaint;
  }
}
