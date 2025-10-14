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
import '../../../../data/datasources/maps/models/map_layers.dart';
import '../../../../data/datasources/maps/services/multi_layer_tile_service.dart';
import 'multi_layer_tile_painter.dart';
import 'tile_image_service.dart';

/// -------------------------
/// Vue & projection partagées
/// -------------------------
class ViewTransform {
  const ViewTransform({
    required this.minX, required this.maxX,
    required this.minY, required this.maxY,
    required this.scale, required this.offsetX, required this.offsetY,
  });

  final double minX, maxX, minY, maxY;
  final double scale, offsetX, offsetY;

  Offset project(double x, double y, Size size) {
    final px = offsetX + (x - minX) * scale;
    final py = size.height - offsetY - (y - minY) * scale; // Y logique vers le haut
    return Offset(px, py);
  }

  double get spanX => maxX - minX;
  double get spanY => maxY - minY;
}

/// Widget displaying the course (buoys + start/finish lines) in plan view.
class CourseCanvas extends ConsumerWidget {
  const CourseCanvas({super.key});

  static const double _margin = 24.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final course = ref.watch(courseProvider);
    final route = ref.watch(routePlanProvider);
    final wind = ref.watch(windSampleProvider);
    final vmcUp = ref.watch(vmcUpwindProvider); // Pour laylines (angle optimal de près)
    final windTrend = ref.watch(windTrendSnapshotProvider); // Analyse des tendances de vent
    final mercatorService = ref.watch(mercatorCoordinateSystemProvider);
    final activeMap = ref.watch(activeMapProvider); // Carte active sélectionnée
    final displayMaps = ref.watch(mapDisplayProvider); // Affichage activé/désactivé

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
        // -------------------------
        // 1) Calcule la bbox logique commune en coordonnées locales (Mercator)
        // -------------------------
        final localPoints = <Offset>[];
        for (final b in course.buoys) {
          final l = mercatorService.toLocal(b.position);
          localPoints.add(Offset(l.x, l.y));
        }
        for (final line in [course.startLine, course.finishLine]) {
          if (line != null) {
            final p1 = mercatorService.toLocal(line.point1);
            final p2 = mercatorService.toLocal(line.point2);
            localPoints.addAll([Offset(p1.x, p1.y), Offset(p2.x, p2.y)]);
          }
        }

        // Fallback si rien : carré 100x100
        double minX = double.infinity, maxX = double.negativeInfinity;
        double minY = double.infinity, maxY = double.negativeInfinity;
        if (localPoints.isEmpty) {
          minX = 0; maxX = 100; minY = 0; maxY = 100;
        } else {
          for (final o in localPoints) {
            minX = math.min(minX, o.dx);
            maxX = math.max(maxX, o.dx);
            minY = math.min(minY, o.dy);
            maxY = math.max(maxY, o.dy);
          }
        }

        // Forcer une bbox carrée (mêmes règles que l’ancien _CoursePainter)
        var spanX = (maxX - minX).abs() < 1e-6 ? 100 : (maxX - minX);
        var spanY = (maxY - minY).abs() < 1e-6 ? 100 : (maxY - minY);
        if (spanX > spanY) {
          final delta = spanX - spanY;
          minY -= delta / 2; maxY += delta / 2;
          spanY = spanX;
        } else if (spanY > spanX) {
          final delta = spanY - spanX;
          minX -= delta / 2; maxX += delta / 2;
          spanX = spanY;
        }

        final availW = constraints.maxWidth - 2 * _margin;
        final availH = constraints.maxHeight - 2 * _margin;
        final scale = math.min(availW / spanX, availH / spanY);
        final offsetX = (constraints.maxWidth - spanX * scale) / 2;
        final offsetY = (constraints.maxHeight - spanY * scale) / 2;

        final view = ViewTransform(
          minX: minX,
          maxX: maxX,
          minY: minY,
          maxY: maxY,
          scale: scale,
          offsetX: offsetX,
          offsetY: offsetY,
        );

        return Stack(
          children: [
            // -------- Tuiles multi-couches (même projection + même vue) --------
            if (displayMaps && activeMap != null)
              FutureBuilder<List<LayeredTile>>(
                future: _loadMultiLayerTilesForMap(
                  activeMap,
                  course,
                  mercatorService: mercatorService,
                  view: view,
                ),
                builder: (context, snapshot) {
                  // ignore: avoid_print
                  print('MULTI-LAYER DEBUG - FutureBuilder ${activeMap.name}: hasData=${snapshot.hasData}, hasError=${snapshot.hasError}');
                  if (snapshot.hasError) {
                    // ignore: avoid_print
                    print('MULTI-LAYER DEBUG - Erreur: ${snapshot.error}');
                  }
                  if (snapshot.hasData) {
                    // ignore: avoid_print
                    print('MULTI-LAYER DEBUG - ${snapshot.data!.length} tuiles multi-couches chargées pour ${activeMap.name}');
                    return CustomPaint(
                      size: Size(constraints.maxWidth, constraints.maxHeight),
                      painter: MultiLayerTilePainter(
                        snapshot.data!,
                        mercatorService,
                        view,
                        MapLayersConfig.defaultConfig,
                      ),
                    );
                  }
                  return const Center(
                    child: Text('Chargement des tuiles multi-couches...', style: TextStyle(color: Colors.white)),
                  );
                },
              ),

            // -------- Canvas parcours (utilise la même vue) --------
            RepaintBoundary(
              child: CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: _CoursePainter(
                  state: course,
                  route: route,
                  windDirDeg: wind.directionDeg,
                  windSpeed: wind.speed,
                  upwindOptimalAngle: vmcUp?.angleDeg,
                  windTrend: windTrend,
                  mercatorService: mercatorService,
                  view: view,
                ),
              ),
            ),

            // Overlay
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

  Future<List<LayeredTile>> _loadMultiLayerTilesForMap(
    MapTileSet map,
    CourseState course, {
    required MercatorCoordinateSystemService mercatorService,
    required ViewTransform view,
  }) async {
    // ignore: avoid_print
    print('MULTI-LAYER DEBUG - _loadMultiLayerTilesForMap: ${map.id}');
    final mapBasePath = '/home/fefe/home/Kornog/Logiciel/Front-End/app/lib/data/datasources/maps/repositories/downloaded_maps';
    final mapPath = '$mapBasePath/${map.id}';
    // ignore: avoid_print
    print('MULTI-LAYER DEBUG - Chemin des tuiles: $mapPath');

    // BBox géographique dérivée de la vue logique (attention orientation Y)
    final geoTopLeft = mercatorService.toGeographic(LocalPosition(x: view.minX, y: view.maxY));
    final geoBottomRight = mercatorService.toGeographic(LocalPosition(x: view.maxX, y: view.minY));

    final zoom = map.zoomLevel;
    int tileXmin = _lon2tile(geoTopLeft.longitude, zoom);
    int tileXmax = _lon2tile(geoBottomRight.longitude, zoom);
    int tileYmin = _lat2tile(geoTopLeft.latitude, zoom);
    int tileYmax = _lat2tile(geoBottomRight.latitude, zoom);

    if (tileXmin > tileXmax) { final t = tileXmin; tileXmin = tileXmax; tileXmax = t; }
    if (tileYmin > tileYmax) { final t = tileYmin; tileYmin = tileYmax; tileYmax = t; }

    // ignore: avoid_print
    print('MULTI-LAYER DEBUG - Tiles widget: X[$tileXmin;$tileXmax] Y[$tileYmin;$tileYmax] z=$zoom');

    final tiles = <LayeredTile>[];
    final foundFiles = <String>[];

    for (int x = tileXmin; x <= tileXmax; x++) {
      for (int y = tileYmin; y <= tileYmax; y++) {
        final filePath = '$mapPath/${x}_${y}_$zoom.png';
        final file = File(filePath);
        if (await file.exists()) {
          foundFiles.add(filePath);
          final layeredTile = await MultiLayerTileService.loadLayeredTile(
            x: x,
            y: y,
            zoom: zoom,
            config: MapLayersConfig.defaultConfig,
            localMapPath: mapPath,
          );
          tiles.add(layeredTile);
        }
      }
    }

    // ignore: avoid_print
    print('MULTI-LAYER DEBUG - Fichiers trouvés (${foundFiles.length})');
    for (final f in foundFiles) {
      // ignore: avoid_print
      print('  $f');
    }
    // ignore: avoid_print
    print('MULTI-LAYER DEBUG - ${tiles.length} layered tiles chargées');

    return tiles;
  }

  // Conversion latitude/longitude vers numéro de tuile OSM (slippy)
  int _lon2tile(double lon, int zoom) {
    return ((lon + 180.0) / 360.0 * (1 << zoom)).floor();
  }
  int _lat2tile(double lat, int zoom) {
    final rad = lat * math.pi / 180.0;
    return ((1.0 - math.log(math.tan(rad) + 1.0 / math.cos(rad)) / math.pi) / 2.0 * (1 << zoom)).floor();
  }

  // ------ Anciennes fonctions de test direct conservées au besoin ------
  Future<List<LoadedTile>> _loadTilesForMap(MapTileSet map) async {
    // ignore: avoid_print
    print('TILES DEBUG - _loadTilesForMap: ${map.id}');
    const mapBasePath = '/home/fefe/home/Kornog/Logiciel/Front-End/app/lib/data/datasources/maps/repositories/downloaded_maps';
    final tiles = await TileImageService.preloadMapTiles(map.id, mapBasePath);
    // ignore: avoid_print
    print('TILES DEBUG - ${tiles.length} tuiles chargées pour ${map.id}');
    return tiles;
  }

  Future<List<LoadedTile>> _loadTilesDirectly() async {
    // ignore: avoid_print
    print('TILES DEBUG - _loadTilesDirectly');
    const mapPath = '/home/fefe/home/Kornog/Logiciel/Front-End/app/lib/data/datasources/maps/repositories/downloaded_maps';
    const mapId = 'map_1759955517334_43.535_6.999';
    final tiles = await TileImageService.preloadMapTiles(mapId, mapPath);
    // ignore: avoid_print
    print('TILES DEBUG - ${tiles.length} tuiles chargées directement');
    return tiles;
  }
}

/// ----------------------------------------
/// Painter parcours (utilise la vue partagée)
/// ----------------------------------------
class _CoursePainter extends CustomPainter {
  _CoursePainter({
    required this.state,
    required this.route,
    required this.windDirDeg,
    required this.windSpeed,
    required this.upwindOptimalAngle,
    required this.windTrend,
    required this.mercatorService,
    required this.view,
  });

  final CourseState state;
  final RoutePlan route;
  final double windDirDeg; // 0 = Nord (haut), 90 = Est (droite)
  final double windSpeed; // nds
  final double? upwindOptimalAngle; // angle (°) par rapport au vent pour meilleure VMG près
  final WindTrendSnapshot windTrend; // Analyse des tendances de vent
  final MercatorCoordinateSystemService mercatorService;
  final ViewTransform view;

  static const double margin = 24.0; // logical px margin inside canvas
  static const double buoyRadius = 8.0;

  Offset _project(double x, double y, Size size) => view.project(x, y, size);

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
      final fill = Paint()..style = PaintingStyle.fill..color = colors.background;
      final stroke = Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = colors.border;
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
    final headPaint = Paint()..color = Colors.black..style = PaintingStyle.fill;
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

    double twa = (headingDeg - windDirDeg) % 360;
    if (twa > 180) twa -= 360;
    if (twa < -180) twa += 360;
    final absTWA = twa.abs();

    if (absTWA < upwindOptimalAngle!) {
      return 'PRÈS';
    } else if (absTWA > 150) {
      return 'PORTANT';
    }
    return null;
  }

  /// Laylines de près
  void _drawUpwindLaylines(Canvas canvas, Size size, double ox, double oy, String buoyLabel) {
    final heading1 = (windDirDeg + 180.0 - upwindOptimalAngle!) % 360.0; // bâbord
    final heading2 = (windDirDeg + 180.0 + upwindOptimalAngle!) % 360.0; // tribord

    final maxSpan = math.max(view.spanX, view.spanY);
    final length = maxSpan * 1.2;

  void drawLay(double headingDeg, Color color, String side, [double labelT = 0.6]) {
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

      const dash = 10.0, gap = 6.0;
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
        final mid = p1 + dir * (total * labelT);
        final displayAngle = (headingDeg + 180) % 360;
        _drawText(canvas, '${displayAngle.toStringAsFixed(0)}° $side ($buoyLabel)', mid + const Offset(5, -10),
            fontSize: 9, color: color.withOpacity(0.9));
      }
    }

    drawLay(heading1, Colors.lightGreenAccent.shade400, 'Bb');
    drawLay(heading2, Colors.lightGreenAccent.shade700, 'Tb');
  }

  /// Laylines de portant (bug corrigé : longueur)
  void _drawDownwindLaylines(Canvas canvas, Size size, double ox, double oy, String buoyLabel) {
    const optimalDownwindAngle = 150.0;
    final downwindHeading1 = (windDirDeg + 180.0 + optimalDownwindAngle) % 360.0; // tribord portant inversé -> bâbord
    final downwindHeading2 = (windDirDeg + 180.0 - optimalDownwindAngle) % 360.0; // bâbord portant inversé -> tribord

    // BUG FIX: maxSpan utilisait maxY - maxY
    final maxSpan = math.max(view.spanX, view.spanY);
    final length = maxSpan * 1.2;

  void drawLay(double headingDeg, Color color, String side, [double labelT = 0.4]) {
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

      const dash = 8.0, gap = 8.0;
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
        final mid = p1 + dir * (total * labelT);
        final displayAngle = headingDeg; // déjà corrigé
        _drawText(canvas, '${displayAngle.toStringAsFixed(0)}° $side ($buoyLabel)', mid + const Offset(5, 8),
            fontSize: 9, color: color.withOpacity(0.9));
      }
    }

    drawLay(downwindHeading1, Colors.orangeAccent.shade400, 'Bb↑');
    drawLay(downwindHeading2, Colors.orangeAccent.shade700, 'Tb↑');
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

    _drawText(canvas, '📊 ANALYSE VENT', const Offset(margin + 8, margin + 8),
        fontSize: 11, color: Colors.white70);

    _drawText(canvas, '$trendIcon $trendLabel', const Offset(margin + 8, margin + 8 + lineHeight),
        fontSize: 13, color: trendColor);

    final slopeText = windTrend.linearSlopeDegPerMin >= 0
        ? '+${windTrend.linearSlopeDegPerMin.toStringAsFixed(1)}°/min'
        : '${windTrend.linearSlopeDegPerMin.toStringAsFixed(1)}°/min';

    _drawText(canvas, 'Pente: $slopeText', const Offset(margin + 8, margin + 8 + lineHeight * 2),
        fontSize: 10, color: Colors.white70);

    final reliability = windTrend.isReliable ? '✓ Fiable' : '⚠ Peu fiable';
    final reliabilityColor = windTrend.isReliable ? Colors.green.shade400 : Colors.orange.shade400;

    _drawText(canvas, '$reliability (${windTrend.supportPoints}pts)',
        const Offset(margin + 8, margin + 8 + lineHeight * 3),
        fontSize: 10, color: reliabilityColor);
  }

  void _drawBoundsInfo(Canvas canvas, Size size) {
    final southWest = mercatorService.toGeographic(LocalPosition(x: view.minX, y: view.minY));
    final northEast = mercatorService.toGeographic(LocalPosition(x: view.maxX, y: view.maxY));

    final localTxt = 'Locale: X:[${view.minX.toStringAsFixed(1)}m ; ${view.maxX.toStringAsFixed(1)}m]  '
        'Y:[${view.minY.toStringAsFixed(1)}m ; ${view.maxY.toStringAsFixed(1)}m]';

    final geoTxt = 'Géo: Lat:[${southWest.latitude.toStringAsFixed(4)}° ; ${northEast.latitude.toStringAsFixed(4)}°]  '
        'Lon:[${southWest.longitude.toStringAsFixed(4)}° ; ${northEast.longitude.toStringAsFixed(4)}°]';

    _drawText(canvas, localTxt, Offset(8, size.height - 34), fontSize: 10, color: Colors.blueGrey);
    _drawText(canvas, geoTxt, Offset(8, size.height - 18), fontSize: 10, color: Colors.green.shade600);
  }

  void _drawText(Canvas canvas, String text, Offset position, {double fontSize = 14, Color color = Colors.black}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: fontSize, color: color)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    tp.paint(canvas, position);
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
        old.view.minX != view.minX || old.view.maxX != view.maxX ||
        old.view.minY != view.minY || old.view.maxY != view.maxY ||
        old.view.scale != view.scale || old.view.offsetX != view.offsetX || old.view.offsetY != view.offsetY;
  }
}

/// Painter placeholder inchangé
class _MapPlaceholderPainter extends CustomPainter {
  const _MapPlaceholderPainter(this.coordinateService);
  final CoordinateSystemService coordinateService;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.blue.withAlpha(100)..style = PaintingStyle.fill;
    final borderPaint = Paint()..color = Colors.blue.withAlpha(180)..style = PaintingStyle.stroke..strokeWidth = 1;

    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        final rect = Rect.fromLTWH(i * 256.0, j * 256.0, 256.0, 256.0);
        if (rect.right > 0 && rect.bottom > 0 && rect.left < size.width && rect.top < size.height) {
          canvas.drawRect(rect, paint);
          canvas.drawRect(rect, borderPaint);
        }
      }
    }

    final textPainter = TextPainter(
      text: const TextSpan(text: 'Chargement des tuiles...', style: TextStyle(color: Colors.white, fontSize: 16)),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(20, size.height - 50));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RoleColors {
  const _RoleColors({required this.background, required this.border, required this.text});
  final Color background;
  final Color border;
  final Color text;
}
