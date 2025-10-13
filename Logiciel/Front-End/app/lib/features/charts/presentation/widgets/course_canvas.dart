import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:io';
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
import '../../providers/coordinate_system_provider.dart';
import '../../providers/mercator_coordinate_system_provider.dart';
import 'coordinate_system_config.dart';

import '../../../../data/datasources/maps/providers/map_providers.dart';
import '../../../../data/datasources/maps/models/map_tile_set.dart';
import '../../../../data/datasources/maps/providers/map_layer.dart';
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
    final vmcUp = ref.watch(vmcUpwindProvider); // Pour laylines (angle optimal de près)
    final windTrend = ref.watch(windTrendSnapshotProvider); // Analyse des tendances de vent
    final mercatorService = ref.watch(mercatorCoordinateSystemProvider);
    final grid = ref.watch(currentGribGridProvider);

    // ⚠️ IMPORTANT : même cadre pour les deux painters
    final courseBounds = computeCourseLocalBounds(course, mercatorService);


    // 🔴 IMPORTANT : recaler l’origine Mercator autour du parcours à chaque build
    _ensureMercatorOrigin(ref, course);

    final activeMap = ref.watch(activeMapProvider); // Carte active sélectionnée
    final displayMaps = ref.watch(mapDisplayProvider); // Affichage activé/désactivé
    final grid = ref.watch(currentGribGridProvider);

    // DEBUG: Vérification de la carte active
    if (displayMaps && activeMap != null) {
      // ignore: avoid_print
      print('TILES DEBUG - Carte active: id=${activeMap.id}, name=${activeMap.name}');
    } else {
      // ignore: avoid_print
      print('TILES DEBUG - Aucune carte active (displayMaps: $displayMaps, activeMap: ${activeMap?.id})');
    }

    if (course.buoys.isEmpty && course.startLine == null && course.finishLine == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Aucune bouée / ligne'),
            SizedBox(height: 16),
            CoordinateSystemInfo(),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            // Affichage des tuiles multi-couches (OSM + OpenSeaMap)
            if (displayMaps && activeMap != null)
              FutureBuilder<List<LayeredTile>>(
                future: _loadMultiLayerTilesForMap(activeMap),
                builder: (context, snapshot) {
                  // ignore: avoid_print
                  print('MULTI-LAYER DEBUG - FutureBuilder pour ${activeMap.name}: hasData=${snapshot.hasData}, hasError=${snapshot.hasError}');
                  if (snapshot.hasError) {
                    // ignore: avoid_print
                    print('MULTI-LAYER DEBUG - Erreur: ${snapshot.error}');
                  }
                  if (snapshot.hasData) {
                    // ignore: avoid_print
                    print('MULTI-LAYER DEBUG - ${snapshot.data!.length} tuiles multi-couches chargées pour rendu de ${activeMap.name}');
                    return CustomPaint(
                      size: Size(constraints.maxWidth, constraints.maxHeight),
                      painter: MultiLayerTilePainter(
                        snapshot.data!,
                        mercatorService,
                        constraints,
                        course,
                        MapLayersConfig.defaultConfig, // Configuration des couches
                      ),
                    );
                  }
                  // Pendant le chargement : message simple
                  return const Center(
                    child: Text('Chargement des tuiles multi-couches...', style: TextStyle(color: Colors.white)),
                  );
                },
              ),

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
                  samplingStride: 1, // pour tester bien net au début
                  localBoundsOverride: courseBounds, // ✅
                  debugDrawCoverage: true,          // ✅ voir le cadre en surimpression
                ),
              ),
            ),

            // Canvas principal avec le parcours
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
                ),
              ),
            ),

            // Coordinate system info overlay (coin haut droit)
            const Positioned(
              top: 8,
              right: 8,
              child: CoordinateSystemInfo(),
            ),
          ],
        );
      },
    );
  }

  /// Charge les tuiles multi-couches (chemin calculé à partir du mapId)
  Future<List<LayeredTile>> _loadMultiLayerTilesForMap(MapTileSet map) async {
    // ⚠️ Adapte ce chemin à ton repo réel si différent (casse incluse).
    const mapBasePath =
        '/home/fefe/home/Kornog/Logiciel/Front-End/app/lib/data/datasources/maps/repositories/downloaded_maps';
    final mapPath = '$mapBasePath/${map.id}';

    // ignore: avoid_print
    print('MULTI-LAYER DEBUG - _loadMultiLayerTilesForMap: mapId=${map.id}, mapPath=$mapPath');

    final tiles = await MultiLayerTileService.preloadLayeredTiles(
      mapId: map.id,
      mapPath: mapPath,
      config: MapLayersConfig.defaultConfig,
    );

    // ignore: avoid_print
    print('MULTI-LAYER DEBUG - ${tiles.length} tuiles multi-couches chargées pour ${map.id}');
    return tiles;
  }

  // (legacy debug helpers conservés si besoin)
  Future<List<LoadedTile>> _loadTilesForMap(MapTileSet map) async {
    // ignore: avoid_print
    print('TILES DEBUG - _loadTilesForMap appelée pour: ${map.id}');
    const mapBasePath =
        '/home/fefe/home/Kornog/Logiciel/Front-End/app/lib/data/datasources/maps/repositories/downloaded_maps';
    // ignore: avoid_print
    print('TILES DEBUG - Chemin de base: $mapBasePath');
    final tiles = await TileImageService.preloadMapTiles(map.id, mapBasePath);
    // ignore: avoid_print
    print('TILES DEBUG - ${tiles.length} tuiles chargées pour ${map.id}');
    return tiles;
  }

  Future<List<LoadedTile>> _loadTilesDirectly() async {
    // ignore: avoid_print
    print('TILES DEBUG - _loadTilesDirectly appelée');
    const mapPath =
        '/home/fefe/home/Kornog/Logiciel/Front-End/app/lib/data/datasources/maps/repositories/downloaded_maps';
    const mapId = 'map_1759955517334_43.535_6.999';
    // ignore: avoid_print
    print('TILES DEBUG - Chargement direct: $mapPath/$mapId');
    final tiles = await TileImageService.preloadMapTiles(mapId, mapPath);
    // ignore: avoid_print
    print('TILES DEBUG - ${tiles.length} tuiles chargées directement');
    return tiles;
  }
}

/// La classe _TilePainter legacy a été remplacée par MultiLayerTilePainter avec projection Mercator

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
  });

  final CourseState state;
  final RoutePlan route;
  final double windDirDeg; // 0 = Nord (haut), 90 = Est (droite)
  final double windSpeed; // nds
  final double? upwindOptimalAngle; // angle (°) pour meilleure VMG près
  final WindTrendSnapshot windTrend; // Analyse des tendances de vent
  final MercatorCoordinateSystemService mercatorService;

  /// (optionnel) imposer un viewport (en mètres locaux)
  final ViewportBounds? viewport;

  static const double margin = 24.0; // logical px margin inside canvas
  static const double buoyRadius = 8.0;

  late final _Bounds _bounds =
      viewport != null
          ? _Bounds(viewport!.minX, viewport!.maxX, viewport!.minY, viewport!.maxY)
          : _computeBounds();

  _Bounds _computeBounds() {
    final xs = <double>[];
    final ys = <double>[];

    // Utiliser la projection Mercator pour toutes les conversions
    for (final b in state.buoys) {
      final localPos = mercatorService.toLocal(b.position);
      xs.add(localPos.x);
      ys.add(localPos.y);
    }

    for (final l in [state.startLine, state.finishLine]) {
      if (l != null) {
        final p1 = mercatorService.toLocal(l.point1);
        final p2 = mercatorService.toLocal(l.point2);
        xs.addAll([p1.x, p2.x]);
        ys.addAll([p1.y, p2.y]);
      }
    }

    if (xs.isEmpty || ys.isEmpty) {
      return const _Bounds(0, 100, 0, 100); // default square
    }
    final minX = xs.reduce(math.min);
    final maxX = xs.reduce(math.max);
    final minY = ys.reduce(math.min);
    final maxY = ys.reduce(math.max);

    // Guard against zero span
    var spanX = (maxX - minX).abs() < 1e-6 ? 100 : maxX - minX;
    var spanY = (maxY - minY).abs() < 1e-6 ? 100 : maxY - minY;

    // Forcer une boîte carrée (échelle 1:1)
    if (spanX > spanY) {
      final delta = spanX - spanY;
      return _Bounds(minX, minX + spanX, minY - delta / 2, minY + spanY + delta / 2);
    } else if (spanY > spanX) {
      final delta = spanY - spanX;
      return _Bounds(minX - delta / 2, minX + spanX + delta / 2, minY, minY + spanY);
    }
    return _Bounds(minX, minX + spanX, minY, minY + spanY);
  }

  Offset _project(double x, double y, Size size) {
    // Un seul facteur d’échelle X/Y pour conserver les angles.
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
    final bg = Paint()
      ..color = Colors.blueGrey.withOpacity(0.04)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Offset.zero & size, bg);

    _drawGrid(canvas, size);
    _drawLines(canvas, size);
    _drawRoute(canvas, size);
    _drawBuoys(canvas, size);
    _drawWind(canvas, size);
    _drawLaylines(canvas, size);
    _drawWindTrendInfo(canvas, size);
    _drawBoundsInfo(canvas, size);
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
      final localP1 = mercatorService.toLocal(line.point1);
      final localP2 = mercatorService.toLocal(line.point2);
      final p1 = _project(localP1.x, localP1.y, size);
      final p2 = _project(localP2.x, localP2.y, size);
      final paint = Paint()
        ..strokeWidth = line.type == LineType.start ? 4 : 3
        ..style = PaintingStyle.stroke
        ..color = line.type == LineType.start ? Colors.greenAccent.shade400 : Colors.redAccent.shade400;
      canvas.drawLine(p1, p2, paint);

      final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
      _drawText(
        canvas,
        line.type == LineType.start ? 'Start' : 'Finish',
        mid + const Offset(4, -16),
        color: paint.color,
        fontSize: 12,
      );
    }
  }

  void _drawBuoys(Canvas canvas, Size size) {
    for (final b in state.buoys) {
      final localPos = mercatorService.toLocal(b.position);
      final p = _project(localPos.x, localPos.y, size);
      final colors = _colorsForRole(b.role);
      final fill = Paint()
        ..style = PaintingStyle.fill
        ..color = colors.background;
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = colors.border;
      canvas.drawCircle(p, buoyRadius, fill);
      canvas.drawCircle(p, buoyRadius, stroke);
      final label = _labelForBuoy(b);
      _drawText(canvas, label, p + const Offset(10, -4), fontSize: 11, color: colors.text);
    }
  }

  void _drawRoute(Canvas canvas, Size size) {
    if (route.isEmpty) return;
    final pathPaint = Paint()
      ..color = Colors.cyanAccent.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final leg in route.legs) {
      final p1 = _project(leg.startX, leg.startY, size);
      final p2 = _project(leg.endX, leg.endY, size);
      canvas.drawLine(p1, p2, pathPaint);

      final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
      _drawText(canvas, _shortLabel(leg), mid + const Offset(4, -10), fontSize: 10, color: Colors.cyan.shade900);
    }
  }

  void _drawWind(Canvas canvas, Size size) {
    const arrowLen = 50.0;
    final toDir = (windDirDeg + 180.0) % 360.0;
    final angleRad = toDir * math.pi / 180.0;
    final vx = math.sin(angleRad);
    final vy = -math.cos(angleRad);

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
    final headP1 = tip;
    final headP2 = tip - Offset(vx, vy) * headSize + ortho * (headSize * 0.6);
    final headP3 = tip - Offset(vx, vy) * headSize - ortho * (headSize * 0.6);
    final headPath = Path()
      ..moveTo(headP1.dx, headP1.dy)
      ..lineTo(headP2.dx, headP2.dy)
      ..lineTo(headP3.dx, headP3.dy)
      ..close();
    final headPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    canvas.drawPath(headPath, headPaint);
    canvas.drawPath(headPath, shaft);

    final label = 'Vent→  from ${windDirDeg.toStringAsFixed(0)}°  ${windSpeed.toStringAsFixed(1)} nds';
    _drawText(canvas, label, base + const Offset(-180, 8), fontSize: 12, color: Colors.black87);
  }

  void _drawLaylines(Canvas canvas, Size size) {
    if (upwindOptimalAngle == null) return;

    final regularBuoys = state.buoys.where((b) => b.role == BuoyRole.regular).toList();
    if (regularBuoys.isEmpty) return;

    regularBuoys.sort((a, b) {
      final ao = a.passageOrder;
      final bo = b.passageOrder;
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

    for (int i = 0; i < regularBuoys.length; i++) {
      final buoy = regularBuoys[i];
      final buoyLocal = mercatorService.toLocal(buoy.position);
      final legType = _analyzeLegTowardsBuoy(buoy, i == 0 ? null : regularBuoys[i - 1]);

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

    final startLocal = mercatorService.toLocal(startPos);
    final endLocal = mercatorService.toLocal(targetBuoy.position);

    final dx = endLocal.x - startLocal.x;
    final dy = endLocal.y - startLocal.y;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist < 1e-6) return null;

    final headingRad = math.atan2(dx, dy);
    double headingDeg = (headingRad * 180 / math.pi) % 360;
    if (headingDeg < 0) headingDeg += 360;

    double theoreticalTWA = (headingDeg - windDirDeg) % 360;
    if (theoreticalTWA > 180) theoreticalTWA -= 360;
    if (theoreticalTWA < -180) theoreticalTWA += 360;

    final absTWA = theoreticalTWA.abs();

    if (absTWA < upwindOptimalAngle!) {
      return 'PRÈS';
    } else if (absTWA > 150) {
      return 'PORTANT';
    }
    return null; // travers
  }

  void _drawUpwindLaylines(Canvas canvas, Size size, double ox, double oy, String buoyLabel) {
    final heading1 = (windDirDeg + 180.0 - upwindOptimalAngle!) % 360.0; // bâbord
    final heading2 = (windDirDeg + 180.0 + upwindOptimalAngle!) % 360.0; // tribord

    final maxSpan = math.max(_bounds.maxX - _bounds.minX, _bounds.maxY - _bounds.minY);
    final length = maxSpan * 1.2;

    void drawUpwindLay(double headingDeg, Color color, String side) {
      final rad = headingDeg * math.pi / 180.0;
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

      const dash = 10.0;
      const gap = 6.0;
      final total = (p2 - p1).distance;
      if (total > 0) {
        final dir = (p2 - p1) / total;
        double dist = 0;
        while (dist < total) {
          final s = p1 + dir * dist;
          final e = p1 + dir * math.min(dist + dash, total);
          canvas.drawLine(s, e, paint);
          dist += dash + gap;
        }

        final midPoint = p1 + dir * (total * 0.6);
        final displayAngle = (headingDeg + 180) % 360;
        _drawText(
          canvas,
          '${displayAngle.toStringAsFixed(0)}° $side ($buoyLabel)',
          midPoint + const Offset(5, -10),
          fontSize: 9,
          color: color.withOpacity(0.9),
        );
      }
    }

    drawUpwindLay(heading1, Colors.lightGreenAccent.shade400, 'Bb');
    drawUpwindLay(heading2, Colors.lightGreenAccent.shade700, 'Tb');
  }

  void _drawDownwindLaylines(Canvas canvas, Size size, double ox, double oy, String buoyLabel) {
    const optimalDownwindAngle = 150.0;

    final downwindHeading1 = (windDirDeg + 180.0 + optimalDownwindAngle) % 360.0; // tribord portant inversé -> bâbord
    final downwindHeading2 = (windDirDeg + 180.0 - optimalDownwindAngle) % 360.0; // bâbord portant inversé -> tribord

    final maxSpan = math.max(_bounds.maxX - _bounds.minX, _bounds.maxY - _bounds.minY);
    final length = maxSpan * 1.2;

    void drawDownwindLay(double headingDeg, Color color, String side) {
      final rad = headingDeg * math.pi / 180.0;
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
      const dash = 8.0;
      const gap = 8.0;
      final total = (p2 - p1).distance;
      if (total > 0) {
        final dir = (p2 - p1) / total;
        double dist = 0;
        while (dist < total) {
          final s = p1 + dir * dist;
          final e = p1 + dir * math.min(dist + dash, total);
          canvas.drawLine(s, e, paint);
          dist += dash + gap;
        }

        final midPoint = p1 + dir * (total * 0.4);
        final displayAngle = headingDeg;
        _drawText(
          canvas,
          '${displayAngle.toStringAsFixed(0)}° $side ($buoyLabel)',
          midPoint + const Offset(5, 8),
          fontSize: 9,
          color: color.withOpacity(0.9),
        );
      }
    }

    drawDownwindLay(downwindHeading1, Colors.orangeAccent.shade400, 'Bb↑');
    drawDownwindLay(downwindHeading2, Colors.orangeAccent.shade700, 'Tb↑');
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
    const margin = 12.0;
    const lineHeight = 16.0;

    Color trendColor;
    String trendIcon;
    String trendLabel;

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

    final background = Paint()
      ..color = Colors.black.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    const boxWidth = 180.0;
    const boxHeight = 70.0;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(margin, margin, boxWidth, boxHeight),
      const Radius.circular(6),
    );
    canvas.drawRRect(rect, background);

    _drawText(
      canvas,
      '📊 ANALYSE VENT',
      const Offset(margin + 8, margin + 8),
      fontSize: 11,
      color: Colors.white70,
    );

    _drawText(
      canvas,
      '$trendIcon $trendLabel',
      const Offset(margin + 8, margin + 8 + lineHeight),
      fontSize: 13,
      color: trendColor,
    );

    final slopeText = windTrend.linearSlopeDegPerMin >= 0
        ? '+${windTrend.linearSlopeDegPerMin.toStringAsFixed(1)}°/min'
        : '${windTrend.linearSlopeDegPerMin.toStringAsFixed(1)}°/min';

    _drawText(
      canvas,
      'Pente: $slopeText',
      const Offset(margin + 8, margin + 8 + lineHeight * 2),
      fontSize: 10,
      color: Colors.white70,
    );

    final reliability = windTrend.isReliable ? '✓ Fiable' : '⚠ Peu fiable';
    final reliabilityColor = windTrend.isReliable ? Colors.green.shade400 : Colors.orange.shade400;

    _drawText(
      canvas,
      '$reliability (${windTrend.supportPoints}pts)',
      const Offset(margin + 8, margin + 8 + lineHeight * 3),
      fontSize: 10,
      color: reliabilityColor,
    );
  }

  void _drawBoundsInfo(Canvas canvas, Size size) {
    final southWest =
        mercatorService.toGeographic(LocalPosition(x: _bounds.minX, y: _bounds.minY));
    final northEast =
        mercatorService.toGeographic(LocalPosition(x: _bounds.maxX, y: _bounds.maxY));

    final localTxt =
        'Locale: X:[${_bounds.minX.toStringAsFixed(1)}m ; ${_bounds.maxX.toStringAsFixed(1)}m]  '
        'Y:[${_bounds.minY.toStringAsFixed(1)}m ; ${_bounds.maxY.toStringAsFixed(1)}m]';

    final geoTxt =
        'Géo: Lat:[${southWest.latitude.toStringAsFixed(4)}° ; ${northEast.latitude.toStringAsFixed(4)}°]  '
        'Lon:[${southWest.longitude.toStringAsFixed(4)}° ; ${northEast.longitude.toStringAsFixed(4)}°]';

    _drawText(canvas, localTxt, Offset(8, size.height - 34),
        fontSize: 10, color: Colors.blueGrey);

    _drawText(canvas, geoTxt, Offset(8, size.height - 18),
        fontSize: 10, color: Colors.green.shade600);
  }

  void _drawText(Canvas canvas, String text, Offset position,
      {double fontSize = 14, Color color = Colors.black}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: fontSize, color: color)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    tp.paint(canvas, position);
  }

  @override
  bool shouldRepaint(covariant _CoursePainter oldDelegate) {
    return oldDelegate.state != state ||
        oldDelegate.route != route ||
        oldDelegate.windDirDeg != windDirDeg ||
        oldDelegate.windSpeed != windSpeed ||
        oldDelegate.upwindOptimalAngle != upwindOptimalAngle ||
        oldDelegate.windTrend != windTrend ||
        oldDelegate.mercatorService.config.origin != mercatorService.config.origin ||
        oldDelegate.viewport != viewport;
  }
}

class LocalBounds {
  final double minX, maxX, minY, maxY;
  const LocalBounds(this.minX, this.maxX, this.minY, this.maxY);
}

/// Calcule un cadre local carré basé sur tes bouées/lignes (même logique que _CoursePainter)
LocalBounds computeCourseLocalBounds(CourseState state, MercatorCoordinateSystemService mercator) {
  final xs = <double>[];
  final ys = <double>[];

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

/// Simple bounds struct (en mètres locaux)
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

/// ─────────────────────────────────────────────────────────────────
/// 🔧 Recalage de l’origine Mercator autour du parcours courant
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
      dLat > 0.1 || dLon > 0.1; // ~6–12 km → recaler

  if (shouldRecentre) {
    ref.read(mercatorCoordinateSystemProvider.notifier).setOrigin(center);
    // ignore: avoid_print
    print('MERCATOR ORIGIN - recentred to ${center.latitude}, ${center.longitude}');
  }
}
