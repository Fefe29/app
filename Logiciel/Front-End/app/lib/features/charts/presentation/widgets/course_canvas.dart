import 'coordinate_system_config.dart';
import 'dart:math' as math;
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../charts/providers/course_providers.dart';
import '../../domain/models/course.dart';
import '../../../charts/providers/route_plan_provider.dart';
import '../../../charts/domain/services/routing_calculator.dart';
import 'package:kornog/common/providers/app_providers.dart';
import '../../../charts/providers/polar_providers.dart';
import '../../../charts/providers/wind_trend_provider.dart';
import '../../../charts/domain/services/wind_trend_analyzer.dart';

import '../../domain/models/geographic_position.dart';
import '../../providers/mercator_coordinate_system_provider.dart';

import '../../../../data/datasources/maps/providers/map_providers.dart';
import '../../../../data/datasources/maps/models/map_tile_set.dart';
import '../../../../data/datasources/maps/models/map_layer.dart';
import '../../../../data/datasources/maps/services/multi_layer_tile_service.dart';

import 'multi_layer_tile_painter.dart';
import 'tile_image_service.dart';

import '../../../../data/datasources/gribs/grib_overlay_models.dart';
import '../../../../data/datasources/gribs/grib_overlay_providers.dart';
import '../../../../data/datasources/gribs/grib_raster_painter.dart';

import 'viewport_bounds.dart';

/// Widget displaying the course (buoys + start/finish lines) in plan view.
class CourseCanvas extends ConsumerWidget {
  const CourseCanvas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final course = ref.watch(courseProvider);
    final route = ref.watch(routePlanProvider);
    final wind = ref.watch(windSampleProvider);
    final vmcUp = ref.watch(vmcUpwindProvider);
    final windTrend = ref.watch(windTrendSnapshotProvider);
    final mercatorService = ref.watch(mercatorCoordinateSystemProvider);
    final grid = ref.watch(currentGribGridProvider);

    // Recalage de l’origine Mercator autour du parcours
    _ensureMercatorOrigin(ref, course);

    // Même cadre pour tous les painters
    final courseBounds = computeCourseLocalBounds(course, mercatorService);

    final activeMap = ref.watch(activeMapProvider);
    final displayMaps = ref.watch(mapDisplayProvider);

    if (displayMaps && activeMap != null) {
      dev.log('TILES DEBUG - Carte active: id=${activeMap.id}, name=${activeMap.name}');
    } else {
      dev.log('TILES DEBUG - Aucune carte active (displayMaps: $displayMaps, activeMap: ${activeMap?.id})');
    }

    if (course.buoys.isEmpty && course.startLine == null && course.finishLine == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Aucune bouée / ligne'),
            const SizedBox(height: 16),
            CoordinateSystemInfo(),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            // 1. Tuiles carte (fond)
            if (displayMaps && activeMap != null)
              FutureBuilder<List<LayeredTile>>(
                future: _loadMultiLayerTilesForMap(activeMap),
                builder: (context, snapshot) {
                  dev.log('MULTI-LAYER DEBUG - FB ${activeMap.name}: hasData=${snapshot.hasData}, hasError=${snapshot.hasError}');
                  if (snapshot.hasError) dev.log('MULTI-LAYER ERROR - ${snapshot.error}');
                  if (snapshot.hasData) {
                    dev.log('MULTI-LAYER DEBUG - ${snapshot.data!.length} tuiles prêtes pour ${activeMap.name}');
                    return CustomPaint(
                      size: Size(constraints.maxWidth, constraints.maxHeight),
                      painter: MultiLayerTilePainter(
                        snapshot.data!,
                        mercatorService,
                        constraints,
                        course,
                        MapLayersConfig.defaultConfig,
                      ),
                    );
                  }
                  return const Center(
                    child: Text('Chargement des tuiles multi-couches...', style: TextStyle(color: Colors.white)),
                  );
                },
              ),

            // 2. GRIB (optionnel)
            if (grid != null)
              RepaintBoundary(
                child: CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: GribRasterPainter(
                    grid: grid,
                    mercator: mercatorService,
                    opacity: ref.watch(gribOpacityProvider),
                    colormap: makeLinearColormap(
                      vmin: ref.watch(gribVminProvider),
                      vmax: ref.watch(gribVmaxProvider),
                      stops: const [Colors.blue, Colors.cyan, Colors.yellow, Colors.red],
                    ),
                    samplingStride: 1,
                    localBoundsOverride: courseBounds,
                    debugDrawCoverage: true,
                  ),
                ),
              ),

            // 3. Parcours et debug (doit être après les tuiles et GRIB)
            RepaintBoundary(
              child: CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: _CoursePainter(
                  course,
                  route,
                  wind.directionDeg,
                  wind.speed,
                  vmcUp?.angleDeg,
                  windTrend,
                  mercatorService,
                  viewport: ViewportBounds(
                    minX: courseBounds.minX,
                    maxX: courseBounds.maxX,
                    minY: courseBounds.minY,
                    maxY: courseBounds.maxY,
                  ),
                  debugDrawViewport: true,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Charge les tuiles multi-couches
  Future<List<LayeredTile>> _loadMultiLayerTilesForMap(MapTileSet map) async {
    const mapBasePath =
        '/home/fefe/home/Kornog/Logiciel/Front-End/app/lib/data/datasources/maps/repositories/downloaded_maps';
    final mapPath = '$mapBasePath/${map.id}';
    dev.log('MULTI-LAYER DEBUG - preload mapId=${map.id}, path=$mapPath');

    final tiles = await MultiLayerTileService.preloadLayeredTiles(
      mapId: map.id,
      mapPath: mapPath,
      config: MapLayersConfig.defaultConfig,
    );
    dev.log('MULTI-LAYER DEBUG - tiles=${tiles.length} pour ${map.id}');
    return tiles;
  }
}

/// Overlay bleu (tout en haut)
class _HardDebugOverlayPainterBlue extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // cadre bleu épais
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = Colors.blueAccent;
    canvas.drawRect(Offset.zero & size, border);

    // gros texte au centre
    final tp = TextPainter(
      text: const TextSpan(
        text: 'OVERLAY BLUE ON TOP',
        style: TextStyle(fontSize: 22, color: Colors.blueAccent, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((size.width - tp.width) / 2, 8));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// ─────────────────────────────────────────────────────────────
/// Painter principal
class _CoursePainter extends CustomPainter {
  _CoursePainter(
    this.state,
    this.route,
    this.windDirDeg,
    this.windSpeed,
    this.upwindOptimalAngle,
    this.windTrend,
    this.mercatorService, {
    this.viewport,
    this.debugDrawViewport = false,
  });

  final CourseState state;
  final RoutePlan route;
  final double windDirDeg;
  final double windSpeed;
  final double? upwindOptimalAngle;
  final WindTrendSnapshot windTrend;
  final MercatorCoordinateSystemService mercatorService;

  final ViewportBounds? viewport;
  final bool debugDrawViewport;

  static const double margin = 24.0;
  static const double buoyRadius = 8.0;

  late final _Bounds _bounds =
      viewport != null
          ? _Bounds(viewport!.minX, viewport!.maxX, viewport!.minY, viewport!.maxY)
          : _computeBounds();

  _Bounds _computeBounds() {
    final xs = <double>[], ys = <double>[];
    for (final b in state.buoys) {
      final p = mercatorService.toLocal(b.position);
      xs.add(p.x); ys.add(p.y);
    }
    for (final l in [state.startLine, state.finishLine]) {
      if (l != null) {
        final p1 = mercatorService.toLocal(l.point1);
        final p2 = mercatorService.toLocal(l.point2);
        xs.addAll([p1.x, p2.x]);
        ys.addAll([p1.y, p2.y]);
      }
    }
    if (xs.isEmpty || ys.isEmpty) return const _Bounds(0, 100, 0, 100);

    final minX = xs.reduce(math.min), maxX = xs.reduce(math.max);
    final minY = ys.reduce(math.min), maxY = ys.reduce(math.max);

    var spanX = (maxX - minX).abs() < 1e-6 ? 100 : maxX - minX;
    var spanY = (maxY - minY).abs() < 1e-6 ? 100 : maxY - minY;

    if (spanX > spanY) {
      final d = spanX - spanY;
      return _Bounds(minX, minX + spanX, minY - d / 2, minY + spanY + d / 2);
    } else if (spanY > spanX) {
      final d = spanY - spanX;
      return _Bounds(minX - d / 2, minX + spanX + d / 2, minY, minY + spanY);
    }
    return _Bounds(minX, minX + spanX, minY, minY + spanY);
  }

  Offset _project(double x, double y, Size size) {
    final availW = size.width - 2 * margin;
    final availH = size.height - 2 * margin;
    final spanX = _bounds.maxX - _bounds.minX;
    final spanY = _bounds.maxY - _bounds.minY;
    final scale = math.min(availW / spanX, availH / spanY);
    final offsetX = (size.width - spanX * scale) / 2;
    final offsetY = (size.height - spanY * scale) / 2;
    final px = offsetX + (x - _bounds.minX) * scale;
    final py = size.height - offsetY - (y - _bounds.minY) * scale;
    return Offset(px, py);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Fond léger
    final bg = Paint()
      ..color = Colors.blueGrey.withOpacity(0.04)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Offset.zero & size, bg);

    if (debugDrawViewport) _drawViewportDebug(canvas, size);

    _drawGrid(canvas, size);
    _drawLines(canvas, size);
    _drawRoute(canvas, size);
    _drawBuoys(canvas, size);
    _drawWind(canvas, size);
    _drawLaylines(canvas, size);
    _drawWindTrendInfo(canvas, size);
    _drawBoundsInfo(canvas, size);
  }

  void _drawViewportDebug(Canvas canvas, Size size) {
    final p00 = _project(_bounds.minX, _bounds.minY, size);
    final p11 = _project(_bounds.maxX, _bounds.maxY, size);
    final rect = Rect.fromPoints(
      Offset(math.min(p00.dx, p11.dx), math.min(p00.dy, p11.dy)),
      Offset(math.max(p00.dx, p11.dx), math.max(p00.dy, p11.dy)),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.deepPurpleAccent.withOpacity(0.8);
    canvas.drawRect(rect, paint);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..strokeWidth = 1;
    for (double x = margin; x < size.width - margin; x += 60) {
      canvas.drawLine(Offset(x, margin), Offset(x, size.height - margin), paint);
    }
    for (double y = margin; y < size.height - margin; y += 60) {
      canvas.drawLine(Offset(margin, y), Offset(size.width - margin, y), paint);
    }
  }

  void _drawLines(Canvas canvas, Size size) {
    for (final line in [state.startLine, state.finishLine]) {
      if (line == null) continue;
      final p1l = mercatorService.toLocal(line.point1);
      final p2l = mercatorService.toLocal(line.point2);
      final p1 = _project(p1l.x, p1l.y, size);
      final p2 = _project(p2l.x, p2l.y, size);
      final paint = Paint()
        ..strokeWidth = line.type == LineType.start ? 4 : 3
        ..style = PaintingStyle.stroke
        ..color = line.type == LineType.start ? Colors.greenAccent.shade400 : Colors.redAccent.shade400;
      canvas.drawLine(p1, p2, paint);
      final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
      _drawText(canvas, line.type == LineType.start ? 'Start' : 'Finish',
          mid + const Offset(4, -16), color: paint.color, fontSize: 12);
    }
  }

  void _drawBuoys(Canvas canvas, Size size) {
    for (final b in state.buoys) {
      final pl = mercatorService.toLocal(b.position);
      final p = _project(pl.x, pl.y, size);
      final colors = _colorsForRole(b.role);

      final fill = Paint()..color = colors.background;
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = colors.border;

      canvas.drawCircle(p, buoyRadius, fill);
      canvas.drawCircle(p, buoyRadius, stroke);

      _drawText(canvas, _labelForBuoy(b), p + const Offset(10, -4),
          fontSize: 11, color: colors.text);
    }
  }

  void _drawRoute(Canvas canvas, Size size) {
    dev.log('[PAINT] _drawRoute: legs=${route.legs.length}');
    if (route.isEmpty) return;
    final pathPaint = Paint()
      ..color = Colors.cyanAccent.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final dotPaint = Paint()..color = Colors.deepPurple;

    for (final leg in route.legs) {
      final p1 = _project(leg.startX, leg.startY, size);
      final p2 = _project(leg.endX, leg.endY, size);
      canvas.drawLine(p1, p2, pathPaint);
      canvas.drawCircle(p1, 3, dotPaint);
      canvas.drawCircle(p2, 3, dotPaint);
      final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
      _drawText(canvas, _shortLabel(leg), mid + const Offset(4, -10),
          fontSize: 10, color: Colors.cyan.shade900);
    }
  }

  void _drawWind(Canvas canvas, Size size) {
    const arrowLen = 50.0;
    final toDir = (windDirDeg + 180.0) % 360.0;
    final a = toDir * math.pi / 180.0;
    final vx = math.sin(a);
    final vy = -math.cos(a);

    final base = Offset(size.width - margin - 120, margin + 10);
    final tip = base + Offset(vx, vy) * arrowLen;

    final shaft = Paint()
      ..color = Colors.black
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(base, tip, shaft);

    final headSize = 10.0;
    final ortho = Offset(-vy, vx);
    final head = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo((tip - Offset(vx, vy) * headSize + ortho * (headSize * 0.6)).dx,
               (tip - Offset(vx, vy) * headSize + ortho * (headSize * 0.6)).dy)
      ..lineTo((tip - Offset(vx, vy) * headSize - ortho * (headSize * 0.6)).dx,
               (tip - Offset(vx, vy) * headSize - ortho * (headSize * 0.6)).dy)
      ..close();
    final headPaint = Paint()..color = Colors.black;
    canvas.drawPath(head, headPaint);
    canvas.drawPath(head, shaft);

    final label = 'Vent→  from ${windDirDeg.toStringAsFixed(0)}°  ${windSpeed.toStringAsFixed(1)} nds';
    _drawText(canvas, label, base + const Offset(-180, 8),
        fontSize: 12, color: Colors.black87);
  }

  void _drawLaylines(Canvas canvas, Size size) {
    if (upwindOptimalAngle == null) return;
    final regs = state.buoys.where((b) => b.role == BuoyRole.regular).toList();
    if (regs.isEmpty) return;

    regs.sort((a, b) {
      final ao = a.passageOrder, bo = b.passageOrder;
      if (ao != null && bo != null) {
        final c = ao.compareTo(bo);
        if (c != 0) return c;
      } else if (ao != null) {
        return -1;
      } else if (bo != null) {
        return 1;
      }
      return a.id.compareTo(b.id);
    });

    for (int i = 0; i < regs.length; i++) {
      final buoy = regs[i];
      final buoyLocal = mercatorService.toLocal(buoy.position);
      final legType = _analyzeLegTowardsBuoy(buoy, i == 0 ? null : regs[i - 1]);
      if (legType == 'PRÈS') {
        _drawUpwindLaylines(canvas, size, buoyLocal.x, buoyLocal.y, 'B${buoy.id}');
      } else if (legType == 'PORTANT') {
        _drawDownwindLaylines(canvas, size, buoyLocal.x, buoyLocal.y, 'B${buoy.id}');
      }
    }
  }

  String? _analyzeLegTowardsBuoy(Buoy targetBuoy, Buoy? previousBuoy) {
    if (upwindOptimalAngle == null) return null;

    GeographicPosition startPos;
    if (previousBuoy == null) {
      if (state.startLine != null) {
        final lat = (state.startLine!.point1.latitude + state.startLine!.point2.latitude) / 2;
        final lon = (state.startLine!.point1.longitude + state.startLine!.point2.longitude) / 2;
        startPos = GeographicPosition(latitude: lat, longitude: lon);
      } else {
        startPos = GeographicPosition(
          latitude: targetBuoy.position.latitude - 0.01,
          longitude: targetBuoy.position.longitude,
        );
      }
    } else {
      startPos = previousBuoy.position;
    }

    final s = mercatorService.toLocal(startPos);
    final e = mercatorService.toLocal(targetBuoy.position);

    final dx = e.x - s.x;
    final dy = e.y - s.y;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist < 1e-6) return null;

    final headingRad = math.atan2(dx, dy);
    var headingDeg = (headingRad * 180 / math.pi) % 360;
    if (headingDeg < 0) headingDeg += 360;

    var twa = (headingDeg - windDirDeg) % 360;
    if (twa > 180) twa -= 360;
    if (twa < -180) twa += 360;

    final absTWA = twa.abs();
    if (absTWA < upwindOptimalAngle!) return 'PRÈS';
    if (absTWA > 150) return 'PORTANT';
    return null;
  }

  void _drawUpwindLaylines(Canvas canvas, Size size, double ox, double oy, String buoyLabel) {
    final h1 = (windDirDeg + 180.0 - upwindOptimalAngle!) % 360.0;
    final h2 = (windDirDeg + 180.0 + upwindOptimalAngle!) % 360.0;

    final length = math.max(_bounds.maxX - _bounds.minX, _bounds.maxY - _bounds.minY) * 1.2;

    void drawLay(double hdg, Color color, String side) {
      final rad = hdg * math.pi / 180.0;
      final vx = math.sin(rad);
      final vy = math.cos(rad);
      final ex = ox + vx * length;
      final ey = oy + vy * length;

      final p1 = _project(ox, oy, size);
      final p2 = _project(ex, ey, size);

      final paint = Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      const dash = 10.0, gap = 6.0;
      final total = (p2 - p1).distance;
      if (total <= 0) return;

      final dir = (p2 - p1) / total;
      double d = 0;
      while (d < total) {
        final s = p1 + dir * d;
        final e = p1 + dir * math.min(d + dash, total);
        canvas.drawLine(s, e, paint);
        d += dash + gap;
      }

      final mid = p1 + dir * (total * 0.6);
      final displayAngle = (hdg + 180) % 360;
      _drawText(canvas, '${displayAngle.toStringAsFixed(0)}° $side ($buoyLabel)',
          mid + const Offset(5, -10), fontSize: 9, color: color.withOpacity(0.9));
    }

    drawLay(h1, Colors.lightGreenAccent.shade400, 'Bb');
    drawLay(h2, Colors.lightGreenAccent.shade700, 'Tb');
  }

  void _drawDownwindLaylines(Canvas canvas, Size size, double ox, double oy, String buoyLabel) {
    const optimalDownwindAngle = 150.0;
    final h1 = (windDirDeg + 180.0 + optimalDownwindAngle) % 360.0;
    final h2 = (windDirDeg + 180.0 - optimalDownwindAngle) % 360.0;

    final length = math.max(_bounds.maxX - _bounds.minX, _bounds.maxY - _bounds.minY) * 1.2;

    void drawLay(double hdg, Color color, String side) {
      final rad = hdg * math.pi / 180.0;
      final vx = math.sin(rad);
      final vy = math.cos(rad);
      final ex = ox + vx * length;
      final ey = oy + vy * length;

      final p1 = _project(ox, oy, size);
      final p2 = _project(ex, ey, size);

      final paint = Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      const dash = 8.0, gap = 8.0;
      final total = (p2 - p1).distance;
      if (total <= 0) return;

      final dir = (p2 - p1) / total;
      double d = 0;
      while (d < total) {
        final s = p1 + dir * d;
        final e = p1 + dir * math.min(d + dash, total);
        canvas.drawLine(s, e, paint);
        d += dash + gap;
      }

      final mid = p1 + dir * (total * 0.4);
      _drawText(canvas, '${hdg.toStringAsFixed(0)}° $side ($buoyLabel)',
          mid + const Offset(5, 8), fontSize: 9, color: color.withOpacity(0.9));
    }

    drawLay(h1, Colors.orangeAccent.shade400, 'Bb↑');
    drawLay(h2, Colors.orangeAccent.shade700, 'Tb↑');
  }

  String _shortLabel(RouteLeg leg) {
    switch (leg.type) {
      case RouteLegType.start:
        return 'Départ';
      case RouteLegType.finish:
        return 'Arrivée';
      case RouteLegType.leg:
      default:
        return leg.label ?? '';
    }
  }

  String _labelForBuoy(Buoy b) {
    switch (b.role) {
      case BuoyRole.committee:
        return 'Com';
      case BuoyRole.target:
        return 'Vis';
      case BuoyRole.regular:
      default:
        final base = 'B${b.id}';
        if (b.passageOrder != null) return '$base(${b.passageOrder})';
        return base;
    }
  }

  _RoleColors _colorsForRole(BuoyRole role) {
    switch (role) {
      case BuoyRole.committee:
        return _RoleColors(
          background: Colors.white,
          border: Colors.blueGrey.shade800,
          text: Colors.blueGrey.shade900,
        );
      case BuoyRole.target:
        return _RoleColors(
          background: Colors.purpleAccent.shade100,
          border: Colors.purple.shade700,
          text: Colors.purple.shade900,
        );
      case BuoyRole.regular:
      default:
        return _RoleColors(
          background: Colors.amber.shade400,
          border: Colors.orange.shade700,
          text: Colors.black87,
        );
    }
  }

  void _drawWindTrendInfo(Canvas canvas, Size size) {
    const m = 12.0, lh = 16.0;
    Color trendColor;
    String trendIcon, trendLabel;

    switch (windTrend.trend) {
      case WindTrendDirection.veeringRight:
        trendColor = Colors.green.shade700;
        trendIcon = '↗';
        trendLabel = 'BASCULE DROITE';
        break;
      case WindTrendDirection.backingLeft:
        trendColor = Colors.orange.shade700;
        trendIcon = '↙';
        trendLabel = 'BASCULE GAUCHE';
        break;
      case WindTrendDirection.irregular:
        trendColor = Colors.red.shade600;
        trendIcon = '≋';
        trendLabel = 'IRRÉGULIER';
        break;
      case WindTrendDirection.neutral:
        trendColor = Colors.blue.shade600;
        trendIcon = '→';
        trendLabel = 'STABLE';
        break;
    }

    final bg = Paint()
      ..color = Colors.black.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    const boxW = 180.0, boxH = 70.0;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(m, m, boxW, boxH),
      const Radius.circular(6),
    );
    canvas.drawRRect(rect, bg);

    _drawText(canvas, '📊 ANALYSE VENT', const Offset(m + 8, m + 8),
        fontSize: 11, color: Colors.white70);

    _drawText(canvas, '$trendIcon $trendLabel', const Offset(m + 8, m + 8 + lh),
        fontSize: 13, color: trendColor);

    final slopeText = windTrend.linearSlopeDegPerMin >= 0
        ? '+${windTrend.linearSlopeDegPerMin.toStringAsFixed(1)}°/min'
        : '${windTrend.linearSlopeDegPerMin.toStringAsFixed(1)}°/min';
    _drawText(canvas, 'Pente: $slopeText', const Offset(m + 8, m + 8 + lh * 2),
        fontSize: 10, color: Colors.white70);

    final reliability = windTrend.isReliable ? '✓ Fiable' : '⚠ Peu fiable';
    final reliabilityColor =
        windTrend.isReliable ? Colors.green.shade400 : Colors.orange.shade400;
    _drawText(canvas, '$reliability (${windTrend.supportPoints}pts)',
        const Offset(m + 8, m + 8 + lh * 3), fontSize: 10, color: reliabilityColor);
  }

  void _drawBoundsInfo(Canvas canvas, Size size) {
    final sw = mercatorService.toGeographic(LocalPosition(x: _bounds.minX, y: _bounds.minY));
    final ne = mercatorService.toGeographic(LocalPosition(x: _bounds.maxX, y: _bounds.maxY));

    final localTxt =
        'Locale: X:[${_bounds.minX.toStringAsFixed(1)}m ; ${_bounds.maxX.toStringAsFixed(1)}m]  '
        'Y:[${_bounds.minY.toStringAsFixed(1)}m ; ${_bounds.maxY.toStringAsFixed(1)}m]';

    final geoTxt =
        'Géo: Lat:[${sw.latitude.toStringAsFixed(4)}° ; ${ne.latitude.toStringAsFixed(4)}°]  '
        'Lon:[${sw.longitude.toStringAsFixed(4)}° ; ${ne.longitude.toStringAsFixed(4)}°]';

    _drawText(canvas, localTxt, Offset(8, size.height - 34),
        fontSize: 10, color: Colors.blueGrey);
    _drawText(canvas, geoTxt, Offset(8, size.height - 18),
        fontSize: 10, color: Colors.green.shade600);
  }

  void _drawText(Canvas canvas, String text, Offset pos,
      {double fontSize = 14, Color color = Colors.black}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: fontSize, color: color)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    tp.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(covariant _CoursePainter old) {
    return old.state != state ||
        old.route != route ||
        old.windDirDeg != windDirDeg ||
        old.windSpeed != windSpeed ||
        old.upwindOptimalAngle != upwindOptimalAngle ||
        old.windTrend != windTrend ||
        old.mercatorService.config.origin != mercatorService.config.origin ||
        old.viewport != viewport ||
        old.debugDrawViewport != debugDrawViewport;
  }
}

class _Bounds {
  const _Bounds(this.minX, this.maxX, this.minY, this.maxY);
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
}

class _RoleColors {
  const _RoleColors({required this.background, required this.border, required this.text});
  final Color background;
  final Color border;
  final Color text;
}

class LocalBounds {
  final double minX, maxX, minY, maxY;
  const LocalBounds(this.minX, this.maxX, this.minY, this.maxY);
}

/// Calcule un cadre local carré basé sur tes bouées/lignes
LocalBounds computeCourseLocalBounds(CourseState state, MercatorCoordinateSystemService mercator) {
  final xs = <double>[], ys = <double>[];

  for (final b in state.buoys) {
    final p = mercator.toLocal(b.position);
    xs.add(p.x); ys.add(p.y);
  }
  for (final l in [state.startLine, state.finishLine]) {
    if (l != null) {
      final p1 = mercator.toLocal(l.point1);
      final p2 = mercator.toLocal(l.point2);
      xs.addAll([p1.x, p2.x]);
      ys.addAll([p1.y, p2.y]);
    }
  }

  if (xs.isEmpty || ys.isEmpty) return const LocalBounds(0, 100, 0, 100);

  final minX = xs.reduce(math.min), maxX = xs.reduce(math.max);
  final minY = ys.reduce(math.min), maxY = ys.reduce(math.max);
  var spanX = (maxX - minX).abs() < 1e-6 ? 100 : maxX - minX;
  var spanY = (maxY - minY).abs() < 1e-6 ? 100 : maxY - minY;

  if (spanX > spanY) {
    final d = spanX - spanY;
    return LocalBounds(minX, minX + spanX, minY - d / 2, minY + spanY + d / 2);
  } else if (spanY > spanX) {
    final d = spanY - spanX;
    return LocalBounds(minX - d / 2, minX + spanX + d / 2, minY, minY + spanY);
  }
  return LocalBounds(minX, minX + spanX, minY, minY + spanY);
}

/// Recalage origine Mercator
void _ensureMercatorOrigin(WidgetRef ref, CourseState course) {
  final merc = ref.read(mercatorCoordinateSystemProvider);
  final currentOrigin = merc.config.origin;

  final positions = <GeographicPosition>[];
  for (final b in course.buoys) positions.add(b.position);
  if (course.startLine != null) {
    positions.add(course.startLine!.point1);
    positions.add(course.startLine!.point2);
  }
  if (course.finishLine != null) {
    positions.add(course.finishLine!.point1);
    positions.add(course.finishLine!.point2);
  }
  if (positions.isEmpty) return;

  double latSum = 0, lonSum = 0;
  for (final p in positions) {
    latSum += p.latitude;
    lonSum += p.longitude;
  }
  final center = GeographicPosition(
    latitude: latSum / positions.length,
    longitude: lonSum / positions.length,
  );

  final dLat = (currentOrigin.latitude - center.latitude).abs();
  final dLon = (currentOrigin.longitude - center.longitude).abs();
  final shouldRecentre =
      (!currentOrigin.latitude.isFinite || !currentOrigin.longitude.isFinite) ||
      (currentOrigin.latitude == 0 && currentOrigin.longitude == 0) ||
      dLat > 0.1 || dLon > 0.1;

  if (shouldRecentre) {
    ref.read(mercatorCoordinateSystemProvider.notifier).setOrigin(center);
  }
}
