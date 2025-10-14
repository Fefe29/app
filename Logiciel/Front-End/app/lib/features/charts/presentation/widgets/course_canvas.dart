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
import '../../../charts/providers/zoom_provider.dart';

/// Utilitaire pour centraliser le calcul de bounding box, scale et offset
class CanvasTransform {
  final double minX, maxX, minY, maxY, margin, width, height, userZoom;
  late final double spanX = (maxX - minX).abs() < 1e-6 ? 100 : maxX - minX;
  late final double spanY = (maxY - minY).abs() < 1e-6 ? 100 : maxY - minY;
  late final double scale = userZoom * (width - 2 * margin) / (spanX > spanY ? spanX : spanY);
  late final double offsetX = (width - (maxX - minX) * scale) / 2;
  late final double offsetY = (height - (maxY - minY) * scale) / 2;

  CanvasTransform({
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.margin,
    required this.width,
    required this.height,
    this.userZoom = 1.0,
  });

  Offset project(double x, double y) {
    final px = offsetX + (x - minX) * scale;
    final py = height - offsetY - (y - minY) * scale;
    return Offset(px, py);
  }

  Offset screenToLocal(double px, double py) {
    final x = ((px - offsetX) / scale) + minX;
    final y = ((height - py - offsetY) / scale) + minY;
    return Offset(x, y);
  }
}

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
    final activeMap = ref.watch(activeMapProvider); // Carte active sélectionnée
    final displayMaps = ref.watch(mapDisplayProvider); // Affichage activé/désactivé
    
    // DEBUG: Vérification de la carte active
    if (displayMaps && activeMap != null) {
      print('TILES DEBUG - Carte active: id=${activeMap.id}, name=${activeMap.name}');
    } else {
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
        final userZoom = ref.watch(zoomProvider);
        return Stack(
          children: [
            // Affichage des tuiles multi-couches (OSM + OpenSeaMap)
            if (displayMaps && activeMap != null)
              FutureBuilder<List<LayeredTile>>(
                future: _loadMultiLayerTilesForMap(activeMap, course, constraints: constraints, userZoom: userZoom),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    print('MULTI-LAYER DEBUG - Erreur: \\${snapshot.error}');
                  }
                  if (snapshot.hasData) {
                    return CustomPaint(
                      size: Size(constraints.maxWidth, constraints.maxHeight),
                      painter: MultiLayerTilePainter(
                        snapshot.data!,
                        mercatorService,
                        constraints,
                        course,
                        MapLayersConfig.defaultConfig,
                        userZoom: userZoom,
                      ),
                    );
                  }
                  return const Center(
                    child: Text('Chargement des tuiles multi-couches...', style: TextStyle(color: Colors.white)),
                  );
                },
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
                  userZoom: userZoom,
                ),
              ),
            ),
            // Contrôles de zoom
            Positioned(
              bottom: 16,
              right: 16,
              child: _ZoomControls(),
            ),
            // Coordinate system info overlay
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

  Future<List<LayeredTile>> _loadMultiLayerTilesForMap(MapTileSet map, CourseState course, {BoxConstraints? constraints, double userZoom = 1.0}) async {
    print('MULTI-LAYER DEBUG - _loadMultiLayerTilesForMap appelée pour: ${map.id}');
    final mapBasePath = '/home/fefe/home/Kornog/Logiciel/Front-End/app/lib/data/datasources/maps/repositories/downloaded_maps';
    final mapPath = '$mapBasePath/${map.id}';
    print('MULTI-LAYER DEBUG - Chemin des tuiles: $mapPath');

    // 1. Calculer la bounding box logique qui correspond à tout le widget
    // On utilise la même logique de centrage/échelle que dans _CoursePainter._project
    // On récupère les bounds du parcours pour la projection
    final positions = <GeographicPosition>[];
    for (final b in course.buoys) positions.add(b.position);
    for (final l in [course.startLine, course.finishLine]) {
      if (l != null) {
        positions.add(l.point1);
        positions.add(l.point2);
      }
    }
    if (positions.isEmpty || constraints == null) {
      // Fallback: charger toutes les tuiles
      final tiles = await MultiLayerTileService.preloadLayeredTiles(
        mapId: map.id,
        mapPath: mapPath,
        config: MapLayersConfig.defaultConfig,
      );
      print('MULTI-LAYER DEBUG - ${tiles.length} tuiles multi-couches chargées (fallback) pour ${map.id}');
      return tiles;
    }
    // Calcul des bounds locaux du parcours
    final mercatorService = MercatorCoordinateSystemService(config: MercatorCoordinateSystemConfig(
      origin: map.bounds.center,
      name: map.name,
    ));
    double minX = double.infinity, maxX = double.negativeInfinity;
    double minY = double.infinity, maxY = double.negativeInfinity;
    for (final pos in positions) {
      final local = mercatorService.toLocal(pos);
      minX = math.min(minX, local.x);
      maxX = math.max(maxX, local.x);
      minY = math.min(minY, local.y);
      maxY = math.max(maxY, local.y);
    }
    // Appliquer la logique de _CoursePainter pour obtenir une bounding box carrée
    var spanX = (maxX - minX).abs() < 1e-6 ? 100 : maxX - minX;
    var spanY = (maxY - minY).abs() < 1e-6 ? 100 : maxY - minY;
    double boxMinX = minX, boxMaxX = maxX, boxMinY = minY, boxMaxY = maxY;
    if (spanX > spanY) {
      final delta = spanX - spanY;
      boxMinY = minY - delta / 2;
      boxMaxY = maxY + delta / 2;
    } else if (spanY > spanX) {
      final delta = spanY - spanX;
      boxMinX = minX - delta / 2;
      boxMaxX = maxX + delta / 2;
    }
    // Utilise la classe factorisée pour le calcul de la transformation
    const margin = 24.0;
    final transform = CanvasTransform(
      minX: boxMinX,
      maxX: boxMaxX,
      minY: boxMinY,
      maxY: boxMaxY,
      margin: margin,
      width: constraints.maxWidth,
      height: constraints.maxHeight,
      userZoom: userZoom,
    );
    final localTopLeft = transform.screenToLocal(0, 0);
    final localBottomRight = transform.screenToLocal(constraints.maxWidth, constraints.maxHeight);
    // Convertir en géographique
    final geoTopLeft = mercatorService.toGeographic(LocalPosition(x: localTopLeft.dx, y: localTopLeft.dy));
    final geoBottomRight = mercatorService.toGeographic(LocalPosition(x: localBottomRight.dx, y: localBottomRight.dy));
    // Calculer la plage de tuiles à charger
    final zoom = map.zoomLevel;
    int tileXmin = _lon2tile(geoTopLeft.longitude, zoom);
    int tileXmax = _lon2tile(geoBottomRight.longitude, zoom);
    int tileYmin = _lat2tile(geoTopLeft.latitude, zoom);
    int tileYmax = _lat2tile(geoBottomRight.latitude, zoom);
    // Sécuriser l'ordre
    if (tileXmin > tileXmax) { final tmp = tileXmin; tileXmin = tileXmax; tileXmax = tmp; }
    if (tileYmin > tileYmax) { final tmp = tileYmin; tileYmin = tileYmax; tileYmax = tmp; }
    print('MULTI-LAYER DEBUG - Tiles à charger (widget): X[$tileXmin;$tileXmax] Y[$tileYmin;$tileYmax] zoom=$zoom');
    // Charger les tuiles
    final tiles = <LayeredTile>[];
    final foundFiles = <String>[];
    for (int x = tileXmin; x <= tileXmax; x++) {
      for (int y = tileYmin; y <= tileYmax; y++) {
        final filePath = '$mapPath/${x}_${y}_$zoom.png';
        print('MULTI-LAYER DEBUG - Recherche tuile: $filePath');
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
    print('MULTI-LAYER DEBUG - Fichiers de tuiles trouvés (${foundFiles.length}):');
    for (final f in foundFiles) print('  $f');
    print('MULTI-LAYER DEBUG - ${tiles.length} tuiles multi-couches chargées pour ${map.id} (zone widget)');
    return tiles;
  }

  // Conversion latitude/longitude vers numéro de tuile OSM
  int _lon2tile(double lon, int zoom) {
    return ((lon + 180.0) / 360.0 * (1 << zoom)).floor();
  }
  int _lat2tile(double lat, int zoom) {
    final rad = lat * math.pi / 180.0;
    return ((1.0 - math.log(math.tan(rad) + 1.0 / math.cos(rad)) / math.pi) / 2.0 * (1 << zoom)).floor();
  }

  Future<List<LoadedTile>> _loadTilesForMap(MapTileSet map) async {
    print('TILES DEBUG - _loadTilesForMap appelée pour: ${map.id}');
    // Construire le chemin de base (sans le mapId car preloadMapTiles l'ajoute)
    const mapBasePath = '/home/fefe/home/Kornog/Logiciel/Front-End/app/lib/data/datasources/maps/repositories/downloaded_maps';
    print('TILES DEBUG - Chemin de base: $mapBasePath');
    final tiles = await TileImageService.preloadMapTiles(map.id, mapBasePath);
    print('TILES DEBUG - ${tiles.length} tuiles chargées pour ${map.id}');
    return tiles;
  }

  Future<List<LoadedTile>> _loadTilesDirectly() async {
    print('TILES DEBUG - _loadTilesDirectly appelée');
    // Chargement direct des tuiles téléchargées
    const mapPath = '/home/fefe/home/Kornog/Logiciel/Front-End/app/lib/data/datasources/maps/repositories/downloaded_maps';
    const mapId = 'map_1759955517334_43.535_6.999';
    print('TILES DEBUG - Chargement direct: $mapPath/$mapId');
    final tiles = await TileImageService.preloadMapTiles(mapId, mapPath);
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
    this.mercatorService,
    {this.userZoom = 1.0}
  );
  
  final CourseState state;
  final RoutePlan route;
  final double windDirDeg; // 0 = Nord (haut), 90 = Est (droite)
  final double windSpeed; // nds
  final double? upwindOptimalAngle; // angle (°) par rapport au vent pour meilleure VMG près
  final WindTrendSnapshot windTrend; // Analyse des tendances de vent
  final MercatorCoordinateSystemService mercatorService;

  static const double margin = 24.0; // logical px margin inside canvas
  final double userZoom;
  static const double buoyRadius = 8.0;

  late final _Bounds _bounds = _computeBounds();

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

    // Pour assurer une échelle cohérente (1:1), on force la bounding box à être carrée.
    if (spanX > spanY) {
      final delta = spanX - spanY;
      // Étendre Y de part et d'autre pour rester centré
      return _Bounds(minX, minX + spanX, minY - delta / 2, minY + spanY + delta / 2);
    } else if (spanY > spanX) {
      final delta = spanY - spanX;
      return _Bounds(minX - delta / 2, minX + spanX + delta / 2, minY, minY + spanY);
    }
    return _Bounds(minX, minX + spanX, minY, minY + spanY);
  }

  late CanvasTransform _transform;
  Offset _project(double x, double y, Size size) => _transform.project(x, y);

  @override
  void paint(Canvas canvas, Size size) {
    _transform = CanvasTransform(
      minX: _bounds.minX,
      maxX: _bounds.maxX,
      minY: _bounds.minY,
      maxY: _bounds.maxY,
      margin: margin,
      width: size.width,
      height: size.height,
      userZoom: userZoom,
    );
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
    const gridStep = 50.0; // logical units after projection (approx)
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..strokeWidth = 1;
    // We'll draw an approximate grid in screen space every 60 px
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
      // Convert geographic coordinates to local using Mercator projection
      final localP1 = mercatorService.toLocal(line.point1);
      final localP2 = mercatorService.toLocal(line.point2);
      final p1 = _project(localP1.x, localP1.y, size);
      final p2 = _project(localP2.x, localP2.y, size);
      final paint = Paint()
        ..strokeWidth = line.type == LineType.start ? 4 : 3
        ..style = PaintingStyle.stroke
        ..color = line.type == LineType.start ? Colors.greenAccent.shade400 : Colors.redAccent.shade400;
      canvas.drawLine(p1, p2, paint);
      // Label at midpoint
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
      // Convert geographic coordinates to local using Mercator projection
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
      // Optionnel : petit marqueur
      final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
      
      // Afficher seulement le nom du segment
      _drawText(canvas, _shortLabel(leg), mid + const Offset(4, -10), fontSize: 10, color: Colors.cyan.shade900);
    }
  }

  void _drawWind(Canvas canvas, Size size) {
    // Flèche montrant la direction VERS laquelle souffle le vent (sens inverse de la provenance).
    // Direction FROM = windDirDeg. Direction TO = windDirDeg + 180°.
    const arrowLen = 50.0; // Réduit de 70 à 50
    final toDir = (windDirDeg + 180.0) % 360.0;
    final angleRad = toDir * math.pi / 180.0;
    // Vecteur écran (0°=Nord => vers le haut => y négatif) donc : x=sin, y=-cos
    final vx = math.sin(angleRad);
    final vy = -math.cos(angleRad);

    final base = Offset(size.width - margin - 120, margin + 10); // Décalé plus à gauche
    final tip = base + Offset(vx, vy) * arrowLen;

    final shaft = Paint()
      ..color = Colors.black // Changé en noir
      ..strokeWidth = 3 // Réduit de 4 à 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(base, tip, shaft);

    // Triangle tête pointant vers la DESTINATION du vent.
    final headSize = 10.0; // Réduit de 12 à 10
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
      ..color = Colors.black // Changé en noir
      ..style = PaintingStyle.fill;
    canvas.drawPath(headPath, headPaint);
    canvas.drawPath(headPath, shaft);

    final label = 'Vent→  from ${windDirDeg.toStringAsFixed(0)}°  ${windSpeed.toStringAsFixed(1)} nds';
    _drawText(canvas, label, base + const Offset(-180, 8), fontSize: 12, color: Colors.black87); // Ajusté position et couleur
  }

  void _drawLaylines(Canvas canvas, Size size) {
    if (upwindOptimalAngle == null || windDirDeg == null) return;
    
    // Pour l'instant, analyse simplifiée : laylines de près sur premières bouées, portant sur dernières
    final regularBuoys = state.buoys.where((b) => b.role == BuoyRole.regular).toList();
    if (regularBuoys.isEmpty) return;
    
    // Trier par passageOrder puis par id
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
    
    // Analyse simplifiée du parcours selon la direction générale du vent
    for (int i = 0; i < regularBuoys.length; i++) {
      final buoy = regularBuoys[i];
      final buoyLocal = mercatorService.toLocal(buoy.position);
      
      // Analyser le type de bord pour atteindre cette bouée
      final legType = _analyzeLegTowardsBuoy(buoy, i == 0 ? null : regularBuoys[i - 1]);
      
      if (legType == 'PRÈS') {
        // Si on fait du près pour atteindre cette bouée → laylines de près depuis cette bouée
        _drawUpwindLaylines(canvas, size, buoyLocal.x, buoyLocal.y, 'B${buoy.id}');
      } else if (legType == 'PORTANT') {
        // Si on fait du portant pour atteindre cette bouée → laylines de portant depuis cette bouée
        _drawDownwindLaylines(canvas, size, buoyLocal.x, buoyLocal.y, 'B${buoy.id}');
      }
    }
  }
  
  /// Analyse le type de bord nécessaire pour atteindre une bouée
  String? _analyzeLegTowardsBuoy(Buoy targetBuoy, Buoy? previousBuoy) {
    if (windDirDeg == null || upwindOptimalAngle == null) return null;
    
    // Déterminer le point de départ
    GeographicPosition startPos;
    if (previousBuoy == null) {
      // Premier bord : depuis la ligne de départ ou point arbitraire
      if (state.startLine != null) {
        final lat = (state.startLine!.point1.latitude + state.startLine!.point2.latitude) / 2;
        final lon = (state.startLine!.point1.longitude + state.startLine!.point2.longitude) / 2;
        startPos = GeographicPosition(latitude: lat, longitude: lon);
      } else {
        // Point arbitraire au sud de la bouée
        startPos = GeographicPosition(
          latitude: targetBuoy.position.latitude - 0.01,
          longitude: targetBuoy.position.longitude,
        );
      }
    } else {
      startPos = previousBuoy.position;
    }
    
    // Calculer le bearing requis et le TWA avec projection Mercator
    final startLocal = mercatorService.toLocal(startPos);
    final endLocal = mercatorService.toLocal(targetBuoy.position);
    
    final dx = endLocal.x - startLocal.x;
    final dy = endLocal.y - startLocal.y;
    final dist = math.sqrt(dx * dx + dy * dy);
    
    if (dist < 1e-6) return null;
    
    // Heading géographique (0=N, 90=E)
    final headingRad = math.atan2(dx, dy);
    double headingDeg = (headingRad * 180 / math.pi) % 360;
    if (headingDeg < 0) headingDeg += 360;
    
    // Calculer le TWA théorique
    double theoreticalTWA = (headingDeg - windDirDeg!) % 360;
    if (theoreticalTWA > 180) theoreticalTWA -= 360;
    if (theoreticalTWA < -180) theoreticalTWA += 360;
    
    final absTWA = theoreticalTWA.abs();
    
    // Déterminer le type de bord
    if (absTWA < upwindOptimalAngle!) {
      return 'PRÈS';
    } else if (absTWA > 150) {
      return 'PORTANT';
    }
    return null; // Pas de laylines pour le travers
  }



  /// Dessine les laylines de près depuis une bouée
  void _drawUpwindLaylines(Canvas canvas, Size size, double ox, double oy, String buoyLabel) {
    // windDirDeg représente la DIRECTION D'OU PROVIENT le vent (FROM). Pour remonter au vent,
    // les laylines montrent la DIRECTION DE NAVIGATION du bateau (cap + 180° par rapport au vent).
    // Caps de navigation au près = (windDirDeg + 180°) +/- upwindOptimalAngle.
    final heading1 = (windDirDeg! + 180.0 - upwindOptimalAngle!) % 360.0; // tack bâbord 
    final heading2 = (windDirDeg! + 180.0 + upwindOptimalAngle!) % 360.0; // tack tribord

    final maxSpan = math.max(_bounds.maxX - _bounds.minX, _bounds.maxY - _bounds.minY);
    final length = maxSpan * 1.2; // un peu plus grand que le terrain

    void drawUpwindLay(double headingDeg, Color color, String side) {
      final rad = headingDeg * math.pi / 180.0;
      // Convertir heading (0=N) en vecteur coordonnées logiques (Y vers le haut) : x=sin, y=cos
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
      // Trait en pointillés léger
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
        
        // Afficher l'angle de la layline
        final midPoint = p1 + dir * (total * 0.6); // Position à 60% de la ligne
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

    drawUpwindLay(heading1, Colors.lightGreenAccent.shade400, 'Bb');  // Bâbord
    drawUpwindLay(heading2, Colors.lightGreenAccent.shade700, 'Tb');  // Tribord
  }

  /// Dessine les laylines de portant depuis une bouée
  void _drawDownwindLaylines(Canvas canvas, Size size, double ox, double oy, String buoyLabel) {
    // Angle optimal de portant (typiquement 140-160° TWA)
    const optimalDownwindAngle = 150.0;
    
    // Caps au portant optimaux inversés (navigation depuis la bouée de portant VERS le haut)
    // Avec inversion tribord/bâbord et ajout de 180° pour corriger le sens
    final downwindHeading1 = (windDirDeg! + 180.0 + optimalDownwindAngle) % 360.0; // tribord portant inversé -> bâbord
    final downwindHeading2 = (windDirDeg! + 180.0 - optimalDownwindAngle) % 360.0; // bâbord portant inversé -> tribord
    
    final maxSpan = math.max(_bounds.maxX - _bounds.minX, _bounds.maxY - _bounds.maxY);
    final length = maxSpan * 1.2; // un peu plus grand que le terrain
    
    void drawDownwindLay(double headingDeg, Color color, String side) {
      final rad = headingDeg * math.pi / 180.0;
      // Convertir heading (0=N) en vecteur coordonnées logiques (Y vers le haut) : x=sin, y=cos
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
      // Trait en pointillés avec un pattern différent pour le portant
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
        
        // Afficher l'angle de la layline (avec correction de 180° car on remonte)
        final midPoint = p1 + dir * (total * 0.4); // Position à 40% pour éviter chevauchement avec près
        final displayAngle = headingDeg; // Pas de +180 car déjà corrigé dans le calcul du cap
        _drawText(
          canvas,
          '${displayAngle.toStringAsFixed(0)}° $side ($buoyLabel)',
          midPoint + const Offset(5, 8),
          fontSize: 9,
          color: color.withOpacity(0.9),
        );
      }
    }
    
    drawDownwindLay(downwindHeading1, Colors.orangeAccent.shade400, 'Bb↑');  // Bâbord portant remontant (inversé)
    drawDownwindLay(downwindHeading2, Colors.orangeAccent.shade700, 'Tb↑');  // Tribord portant remontant (inversé)
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
    // Affichage dans le coin supérieur gauche
    const margin = 12.0;
    const lineHeight = 16.0;
    
    // Couleur et style selon la tendance détectée
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
    
    // Fond semi-transparent
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
    
    // Titre
    _drawText(
      canvas, 
      '📊 ANALYSE VENT',
      const Offset(margin + 8, margin + 8),
      fontSize: 11,
      color: Colors.white70,
    );
    
    // Tendance principale avec icône
    _drawText(
      canvas,
      '$trendIcon $trendLabel',
      const Offset(margin + 8, margin + 8 + lineHeight),
      fontSize: 13,
      color: trendColor,
    );
    
    // Pente et fiabilité
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
    
    // Fiabilité
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
    // Convert bounds back to geographic coordinates using Mercator
    final southWest = mercatorService.toGeographic(LocalPosition(x: _bounds.minX, y: _bounds.minY));
    final northEast = mercatorService.toGeographic(LocalPosition(x: _bounds.maxX, y: _bounds.maxY));
    
    final localTxt = 'Locale: X:[${_bounds.minX.toStringAsFixed(1)}m ; ${_bounds.maxX.toStringAsFixed(1)}m]  '
        'Y:[${_bounds.minY.toStringAsFixed(1)}m ; ${_bounds.maxY.toStringAsFixed(1)}m]';
    
    final geoTxt = 'Géo: Lat:[${southWest.latitude.toStringAsFixed(4)}° ; ${northEast.latitude.toStringAsFixed(4)}°]  '
        'Lon:[${southWest.longitude.toStringAsFixed(4)}° ; ${northEast.longitude.toStringAsFixed(4)}°]';
    
    // Local coordinates
    _drawText(canvas, localTxt, Offset(8, size.height - 34), fontSize: 10, color: Colors.blueGrey);
    
    // Geographic coordinates  
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
  bool shouldRepaint(covariant _CoursePainter oldDelegate) {
    return oldDelegate.state != state ||
        oldDelegate.route != route ||
        oldDelegate.windDirDeg != windDirDeg ||
        oldDelegate.windSpeed != windSpeed ||
        oldDelegate.upwindOptimalAngle != upwindOptimalAngle ||
        oldDelegate.windTrend != windTrend ||
        oldDelegate.mercatorService.config.origin != mercatorService.config.origin;
  }
}


class _ZoomControls extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zoom = ref.watch(zoomProvider);
    return Card(
      elevation: 2,
      color: Colors.white.withOpacity(0.85),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: () => ref.read(zoomProvider.notifier).zoomOut(),
            tooltip: 'Zoom -',
          ),
          Text('${(zoom * 100).toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.bold)),
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: () => ref.read(zoomProvider.notifier).zoomIn(),
            tooltip: 'Zoom +',
          ),
        ],
      ),
    );
  }
}

/// Painter pour afficher des rectangles bleus placeholder quand les tuiles ne sont pas disponibles
class _MapPlaceholderPainter extends CustomPainter {
  const _MapPlaceholderPainter(this.coordinateService);
  
  final CoordinateSystemService coordinateService;
  
  @override
  void paint(Canvas canvas, Size size) {
    print('TILES DEBUG - _MapPlaceholderPainter.paint appelé');
    
    // Dessiner une grille de rectangles bleus 256x256 comme placeholder
    final paint = Paint()
      ..color = Colors.blue.withAlpha(100)
      ..style = PaintingStyle.fill;
    
    final borderPaint = Paint()
      ..color = Colors.blue.withAlpha(180)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    // Grille 3x3 de rectangles 256x256
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        final rect = Rect.fromLTWH(
          i * 256.0, 
          j * 256.0, 
          256.0, 
          256.0
        );
        
        // Seulement si le rectangle est visible dans l'écran
        if (rect.right > 0 && rect.bottom > 0 && 
            rect.left < size.width && rect.top < size.height) {
          canvas.drawRect(rect, paint);
          canvas.drawRect(rect, borderPaint);
        }
      }
    }
    
    // Texte informatif
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'Chargement des tuiles...',
        style: TextStyle(color: Colors.white, fontSize: 16),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(20, size.height - 50));
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
