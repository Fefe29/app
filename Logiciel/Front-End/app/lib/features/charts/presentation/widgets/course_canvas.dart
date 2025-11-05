// FLUTTER & DART
import 'dart:math' as math;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// PROVIDERS & MODELS
import '../../../charts/providers/course_providers.dart';
import '../../../charts/providers/route_plan_provider.dart';
import '../../../charts/providers/polar_providers.dart';
import '../../../charts/providers/wind_trend_provider.dart';
import '../../../charts/domain/services/routing_calculator.dart';
import '../../../charts/domain/services/wind_trend_analyzer.dart';
import '../../domain/models/course.dart';
import '../../domain/models/geographic_position.dart';
import '../../providers/mercator_coordinate_system_provider.dart';
import '../../../../data/datasources/maps/providers/map_providers.dart';
import '../../../../data/datasources/maps/models/map_tile_set.dart';
import '../../../../data/datasources/maps/models/map_layers.dart';
import '../../../../data/datasources/maps/services/multi_layer_tile_service.dart';
import 'multi_layer_tile_painter.dart';
import 'package:kornog/common/providers/app_providers.dart';
import 'zoom_button.dart';
import '../../../../data/datasources/gribs/grib_overlay_providers.dart';
import '../../../../data/datasources/gribs/grib_painters.dart';
import '../../../../data/datasources/gribs/grib_models.dart';
import '../../../../data/datasources/gribs/interpolated_wind_arrows_painter.dart';
import '../../providers/grib_layers_provider.dart';
// -------------------------
// Vue & projection partagées
// -------------------------
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

class CourseCanvas extends ConsumerStatefulWidget {
  const CourseCanvas({super.key});

  static const double _margin = 24.0;

  @override
  ConsumerState<CourseCanvas> createState() => _CourseCanvasState();
}

class _CourseCanvasState extends ConsumerState<CourseCanvas> {
  // Offset de déplacement (pan)
  Offset _panOffset = Offset.zero;
  Offset? _lastPanPosition;
  double _zoomFactor = 1.0; // 1.0 = normal, >1 = zoom in, <1 = zoom out
  int _tileZoomOffset = 0; // Décalage de zoom OSM

  void _incrementZoom() {
    setState(() {
      _zoomFactor *= 1.25;
      print('[ZOOM] _incrementZoom: _zoomFactor=$_zoomFactor, _tileZoomOffset=$_tileZoomOffset');
      _adjustTileZoomIfNeeded();
    });
  }

  void _decrementZoom() {
    setState(() {
      _zoomFactor /= 1.25;
      print('[ZOOM] _decrementZoom: _zoomFactor=$_zoomFactor, _tileZoomOffset=$_tileZoomOffset');
      _adjustTileZoomIfNeeded();
    });
  }

  void _adjustTileZoomIfNeeded() {
    // Désactivé : on ne touche plus au tileZoomOffset, le zoom est totalement libre
    // print('[ZOOM] _adjustTileZoomIfNeeded: _zoomFactor=$_zoomFactor, _tileZoomOffset=$_tileZoomOffset');
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final course = ref.watch(courseProvider);
    final route = ref.watch(routePlanProvider);
    final wind = ref.watch(windSampleProvider);
    final vmcUp = ref.watch(vmcUpwindProvider);
    final windTrend = ref.watch(windTrendSnapshotProvider);
    final mercatorService = ref.watch(mercatorCoordinateSystemProvider);
    final activeMap = ref.watch(activeMapProvider);
    final displayMaps = ref.watch(mapDisplayProvider);
    
    // Auto-load GRIB grids on startup
    ref.watch(autoLoadGribGridProvider);
    
    // Note: Les providers GRIB sont maintenant watchés dans des Consumer séparés
    // pour ne pas déclencher un rebuild entier du LayoutBuilder

    if (course.buoys.isEmpty && course.startLine == null && course.finishLine == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Aucune bouée / ligne'),
            SizedBox(height: 16),
          ],
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Canvas principal - LayoutBuilder seul, ne dépend que du parcours
        LayoutBuilder(
          builder: (context, constraints) {
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
        print('[COURSE_CANVAS_BOUNDS] AVANT ajustements: minX=$minX, maxX=$maxX, minY=$minY, maxY=$maxY, localPoints=${localPoints.length}');
        // Pas de limites artificielles sur spanX/spanY - laisse le zoom totalement libre
        var spanX = (maxX - minX).abs() < 1e-6 ? 1.0 : (maxX - minX).abs();
        var spanY = (maxY - minY).abs() < 1e-6 ? 1.0 : (maxY - minY).abs();
        if (spanX > spanY) {
          final delta = spanX - spanY;
          minY -= delta / 2; maxY += delta / 2;
          spanY = spanX;
        } else if (spanY > spanX) {
          final delta = spanY - spanX;
          minX -= delta / 2; maxX += delta / 2;
          spanX = spanY;
        }
        print('[COURSE_CANVAS_BOUNDS] APRES ajustements: minX=$minX, maxX=$maxX, minY=$minY, maxY=$maxY, spanX=$spanX, spanY=$spanY');
        final availW = constraints.maxWidth - 2 * CourseCanvas._margin;
        final availH = constraints.maxHeight - 2 * CourseCanvas._margin;
        final baseScale = math.min(availW / spanX, availH / spanY);
        final scale = baseScale * _zoomFactor;
        final offsetX = (constraints.maxWidth - spanX * scale) / 2 + _panOffset.dx;
        final offsetY = (constraints.maxHeight - spanY * scale) / 2 + _panOffset.dy;
        final view = ViewTransform(
          minX: minX,
          maxX: maxX,
          minY: minY,
          maxY: maxY,
          scale: scale,
          offsetX: offsetX,
          offsetY: offsetY,
        );
        print('[COURSE_CANVAS_BOUNDS] View: scale=$scale, offsetX=$offsetX, offsetY=$offsetY, zoomFactor=$_zoomFactor');
  int baseTileZoom = activeMap?.zoomLevel ?? 10;
  int tileZoom = (baseTileZoom + _tileZoomOffset).clamp(1, 20);
  print('[TILE] baseTileZoom=$baseTileZoom, _tileZoomOffset=$_tileZoomOffset, tileZoom=$tileZoom, _zoomFactor=$_zoomFactor');


        return Listener(
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) {
              setState(() {
                if (event.scrollDelta.dy < 0) {
                  // Zoom in
                  _zoomFactor *= 1.2;
                } else if (event.scrollDelta.dy > 0) {
                  // Zoom out
                  _zoomFactor /= 1.2;
                }
                _adjustTileZoomIfNeeded();
              });
            }
          },
          child: GestureDetector(
            onScaleStart: (details) {
              _lastPanPosition = details.focalPoint;
            },
            onScaleUpdate: (details) {
              setState(() {
                // Pan (déplacement)
                if (_lastPanPosition != null) {
                  final delta = details.focalPoint - _lastPanPosition!;
                  // Inverser le déplacement vertical (Y)
                  _panOffset += Offset(delta.dx, -delta.dy);
                  _lastPanPosition = details.focalPoint;
                }
                // Zoom (pinch) adouci : on réduit la sensibilité du facteur de scale
                if (details.scale != 1.0) {
                  // Adoucissement : on élève le facteur à la puissance 0.4 (plus proche de 1)
                  final softenedScale = details.scale > 1.0
                      ? 1 + (details.scale - 1) * 0.4
                      : 1 - (1 - details.scale) * 0.4;
                  _zoomFactor *= softenedScale;
                  _adjustTileZoomIfNeeded();
                }
              });
            },
            onScaleEnd: (details) {
              _lastPanPosition = null;
            },
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (displayMaps && activeMap != null)
                    FutureBuilder<List<LayeredTile>>(
                      future: _loadMultiLayerTilesForMap(
                        activeMap.copyWith(zoomLevel: tileZoom),
                        course,
                        mercatorService: mercatorService,
                        view: view,
                        size: Size(constraints.maxWidth, constraints.maxHeight),
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(child: Text('Erreur de chargement des tuiles'));
                        }
                        // Si aucune tuile n'est trouvée, on laisse simplement du blanc (pas de message)
                        if (snapshot.hasData) {
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
                        return Center(child: Text('Chargement des tuiles...'));
                      },
                    ),
                  // Couche GRIB heatmap - avec Consumer pour watcher indépendamment
                  Consumer(
                    builder: (context, ref, child) {
                      final gribGrid = ref.watch(currentGribGridProvider);
                      final gribOpacity = ref.watch(gribOpacityProvider);
                      final gribVmin = ref.watch(gribVminProvider);
                      final gribVmax = ref.watch(gribVmaxProvider);
                      final gribVisible = ref.watch(gribVisibilityProvider);

                      if (gribGrid == null || !gribVisible) return const SizedBox.shrink();

                      return RepaintBoundary(
                        key: ValueKey('grib-heatmap-${gribGrid.hashCode}-${gribVmin}-${gribVmax}'),
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: gribOpacity,
                            child: ClipRect(
                              child: CustomPaint(
                                size: Size(constraints.maxWidth, constraints.maxHeight),
                                painter: GribGridPainter(
                                  grid: gribGrid,
                                  vmin: gribVmin,
                                  vmax: gribVmax,
                                  projector: (lon, lat, size) {
                                    final geoPos = GeographicPosition(latitude: lat, longitude: lon);
                                    final localPos = mercatorService.toLocal(geoPos);
                                    return view.project(localPos.x, localPos.y, size);
                                  },
                                  colorMapName: ColorMap.parula,
                                  opacity: gribOpacity,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  // Couche GRIB vecteurs
                  Consumer(
                    builder: (context, ref, child) {
                      final gribUGrid = ref.watch(currentGribUGridProvider);
                      final gribVGrid = ref.watch(currentGribVGridProvider);
                      final gribOpacity = ref.watch(gribOpacityProvider);
                      final gribVisible = ref.watch(gribVisibilityProvider);
                      final gribVectorCount = ref.watch(gribVectorCountProvider);

                      if (gribUGrid == null || gribVGrid == null || !gribVisible) return const SizedBox.shrink();

                      return RepaintBoundary(
                        key: ValueKey('grib-vectors-${gribUGrid.hashCode}-${gribVGrid.hashCode}'),
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: gribOpacity * 0.9,
                            child: ClipRect(
                              child: CustomPaint(
                                size: Size(constraints.maxWidth, constraints.maxHeight),
                                painter: GribVectorFieldPainter(
                                  uGrid: gribUGrid,
                                  vGrid: gribVGrid,
                                  vmin: 0.0,
                                  vmax: 20.0,
                                  projector: (lon, lat, size) {
                                    final geoPos = GeographicPosition(latitude: lat, longitude: lon);
                                    final localPos = mercatorService.toLocal(geoPos);
                                    return view.project(localPos.x, localPos.y, size);
                                  },
                                  opacity: gribOpacity * 0.9,
                                  samplingStride: 3,
                                  boundsMinX: view.minX,
                                  boundsMaxX: view.maxX,
                                  boundsMinY: view.minY,
                                  boundsMaxY: view.maxY,
                                  targetVectorCount: gribVectorCount,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  // Flèches de vent interpolées
                  Consumer(
                    builder: (context, ref, child) {
                      final gribUGrid = ref.watch(currentGribUGridProvider);
                      final gribVGrid = ref.watch(currentGribVGridProvider);
                      final gribOpacity = ref.watch(gribOpacityProvider);
                      final gribVisible = ref.watch(gribVisibilityProvider);

                      if (gribUGrid == null || gribVGrid == null || !gribVisible) {
                        return const SizedBox.shrink();
                      }

                      return IgnorePointer(
                        child: Opacity(
                          opacity: gribOpacity * 0.6,
                          child: CustomPaint(
                            size: Size(constraints.maxWidth, constraints.maxHeight),
                            painter: InterpolatedWindArrowsPainter(
                              uGrids: [gribUGrid],
                              vGrids: [gribVGrid],
                              timestamps: [DateTime.now()], // FIXME: utiliser les vrais timestamps
                              currentTime: DateTime.now(),
                              view: view,
                              mercatorService: mercatorService,
                              arrowsPerSide: 6,  // 6x6 = 36 flèches, moins dense
                              arrowLength: 80,   // Beaucoup plus grand pour bien voir
                              arrowColor: Colors.deepOrange,
                              opacity: 0.8,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  // Parcours et debug
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
                  Positioned(
                    right: 16,
                    bottom: 32,
                    child: Column(
                      children: [
                        ZoomButton(
                          icon: Icons.add,
                          onTap: _incrementZoom,
                          tooltip: 'Zoomer',
                        ),
                        SizedBox(height: 8),
                        ZoomButton(
                          icon: Icons.remove,
                          onTap: _decrementZoom,
                          tooltip: 'Dézoomer',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        },
      ),
        // Overlay GRIB - complètement en dehors du LayoutBuilder
        Positioned.fill(
          child: Consumer(
            builder: (context, ref, child) {
              // Watch les providers GRIB
              final gribGrid = ref.watch(currentGribGridProvider);
              final gribOpacity = ref.watch(gribOpacityProvider);
              final gribVmin = ref.watch(gribVminProvider);
              final gribVmax = ref.watch(gribVmaxProvider);
              final gribUGrid = ref.watch(currentGribUGridProvider);
              final gribVGrid = ref.watch(currentGribVGridProvider);
              final gribVisible = ref.watch(gribVisibilityProvider);
              final gribVectorCount = ref.watch(gribVectorCountProvider);

              if (!gribVisible || (gribGrid == null && gribUGrid == null)) {
                return const SizedBox.shrink();
              }

              return IgnorePointer(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Les flèches de vent interpolées seront dans le LayoutBuilder
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }



  Future<List<LayeredTile>> _loadMultiLayerTilesForMap(
    MapTileSet map,
    CourseState course, {
    required MercatorCoordinateSystemService mercatorService,
    required ViewTransform view,
    required Size size,
  }) async {
    // ignore: avoid_print
    print('MULTI-LAYER DEBUG - _loadMultiLayerTilesForMap: ${map.id}');
  // Récupérer dynamiquement le chemin de stockage des cartes
  final container = ProviderScope.containerOf(context);
  final mapBasePath = await container.read(mapStorageDirectoryProvider.future);
  final mapPath = '$mapBasePath/${map.id}';
    // ignore: avoid_print
    print('MULTI-LAYER DEBUG - Chemin des tuiles: $mapPath');

    // BBox géographique couvrant tout le widget (projetée depuis les 4 coins du widget en pixels)
    // On projette (0,0), (size.width,0), (0,size.height), (size.width,size.height) en coordonnées locales, puis en géographiques
    // On élargit la bbox de 1.0 tuile de chaque côté pour éviter les bords vides
    const double tileMargin = 1.0;
    List<Offset> widgetCornersPx = [
      Offset(-size.width * tileMargin, -size.height * tileMargin),
      Offset(size.width * (1 + tileMargin), -size.height * tileMargin),
      Offset(-size.width * tileMargin, size.height * (1 + tileMargin)),
      Offset(size.width * (1 + tileMargin), size.height * (1 + tileMargin)),
    ];
    // Inverse de view.project : (px, py) -> (x, y)
    List<LocalPosition> localCorners = widgetCornersPx.map((pt) {
      final x = ((pt.dx - view.offsetX) / view.scale) + view.minX;
      final y = ((size.height - pt.dy - view.offsetY) / view.scale) + view.minY;
      return LocalPosition(x: x, y: y);
    }).toList();
    final geoCorners = localCorners.map((lp) => mercatorService.toGeographic(lp)).toList();
    double minLat = geoCorners.first.latitude, maxLat = geoCorners.first.latitude;
    double minLon = geoCorners.first.longitude, maxLon = geoCorners.first.longitude;
    for (final g in geoCorners) {
      if (g.latitude < minLat) minLat = g.latitude;
      if (g.latitude > maxLat) maxLat = g.latitude;
      if (g.longitude < minLon) minLon = g.longitude;
      if (g.longitude > maxLon) maxLon = g.longitude;
    }

  final zoom = map.zoomLevel;
  // On ajoute une tuile de marge de chaque côté pour garantir la couverture
  int tileXmin = (_lon2tile(minLon, zoom) - 1).floor();
  int tileXmax = (_lon2tile(maxLon, zoom) + 1).ceil();
  int tileYmin = (_lat2tile(maxLat, zoom) - 1).floor(); // attention: Y inversé en tuiles
  int tileYmax = (_lat2tile(minLat, zoom) + 1).ceil();

  if (tileXmin > tileXmax) { final t = tileXmin; tileXmin = tileXmax; tileXmax = t; }
  if (tileYmin > tileYmax) { final t = tileYmin; tileYmin = tileYmax; tileYmax = t; }

    // ignore: avoid_print
    print('MULTI-LAYER DEBUG - Tiles widget (full): X[$tileXmin;$tileXmax] Y[$tileYmin;$tileYmax] z=$zoom');

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
        } else {
          // Log tuile manquante pour debug
          // ignore: avoid_print
          print('MULTI-LAYER DEBUG - Tuile manquante: $filePath');
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

  static const double buoyRadius = 8.0;

  Offset _project(double x, double y, Size size) => view.project(x, y, size);

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..color = Colors.blueGrey.withOpacity(0.04)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Offset.zero & size, bg);

  // Quadrillage supprimé
    _drawLines(canvas, size);
    _drawRoute(canvas, size);
    _drawBuoys(canvas, size);
    _drawWind(canvas, size);
    _drawLaylines(canvas, size);
    _drawWindTrendInfo(canvas, size);
    _drawBoundsInfo(canvas, size);
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
    // Utilise le thème pour choisir la couleur du routage
    final isDark = WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    final pathPaint = Paint()
      ..color = isDark ? Colors.redAccent.shade200 : Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final leg in route.legs) {
      final p1 = _project(leg.startX, leg.startY, size);
      final p2 = _project(leg.endX, leg.endY, size);
      canvas.drawLine(p1, p2, pathPaint);
      final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
  _drawText(canvas, _shortLabel(leg), mid + const Offset(4, -10), fontSize: 10, color: Colors.black);
    }
  }

  void _drawWind(Canvas canvas, Size size) {
    // --- FLECHE DE SENS DU VENT COMMENTEE POUR REUTILISATION ULTERIEURE ---
    /*
    const arrowLen = 50.0;
    final toDir = (windDirDeg + 180.0) % 360.0;
    final angleRad = toDir * math.pi / 180.0;
    final vx = math.sin(angleRad);
    final vy = -math.cos(angleRad);

    // Centré horizontalement, en haut du graph
    const topMargin = 24.0;
    final base = Offset(size.width / 2, topMargin + arrowLen);
    final headSize = 16.0; // taille de la pointe augmentée
    // Le trait s'arrête juste avant la pointe
    final tip = base + Offset(vx, vy) * (arrowLen - headSize + 2);
    final arrowEnd = base + Offset(vx, vy) * arrowLen;

    final shaft = Paint()
      ..color = Colors.black
      ..strokeWidth = 13 // épaisseur fortement augmentée
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(base, tip, shaft);

    final ortho = Offset(-vy, vx);
    final headP1 = arrowEnd;
    final headP2 = arrowEnd - Offset(vx, vy) * headSize + ortho * (headSize * 0.9);
    final headP3 = arrowEnd - Offset(vx, vy) * headSize - ortho * (headSize * 0.9);
    final headPath = Path()
      ..moveTo(headP1.dx, headP1.dy)
      ..lineTo(headP2.dx, headP2.dy)
      ..lineTo(headP3.dx, headP3.dy)
      ..close();
    final headPaint = Paint()..color = Colors.black..style = PaintingStyle.fill;
    canvas.drawPath(headPath, headPaint);
    // Pour donner un contour plus épais à la pointe
    final headBorder = Paint()
      ..color = Colors.black
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(headPath, headBorder);
    // Label supprimé
    */
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
  final heading1 = (windDirDeg + 180.0 - upwindOptimalAngle!) % 360.0; // tribord
  final heading2 = (windDirDeg + 180.0 + upwindOptimalAngle!) % 360.0; // bâbord

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

  drawLay(heading1, Colors.lightGreenAccent.shade700, 'Tb');
  drawLay(heading2, Colors.lightGreenAccent.shade400, 'Bb');
  }

  /// Laylines de portant (bug corrigé : longueur)
  void _drawDownwindLaylines(Canvas canvas, Size size, double ox, double oy, String buoyLabel) {
  const optimalDownwindAngle = 150.0;
  final downwindHeading1 = (windDirDeg + 180.0 + optimalDownwindAngle) % 360.0; // bâbord portant
  final downwindHeading2 = (windDirDeg + 180.0 - optimalDownwindAngle) % 360.0; // tribord portant

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

  drawLay(downwindHeading2, Colors.orangeAccent.shade700, 'Tb↑');
  drawLay(downwindHeading1, Colors.orangeAccent.shade400, 'Bb↑');
  }

  String _shortLabel(RouteLeg leg) {
    switch (leg.type) {
      case RouteLegType.start:
        return 'Départ';
      case RouteLegType.finish:
        return 'Arrivée';
      case RouteLegType.leg:
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
        final base = 'B${b.id}';
        if (b.passageOrder != null) return '$base(${b.passageOrder})';
        return base;
    }
  }

  void _drawWindTrendInfo(Canvas canvas, Size size) {
  // Nouvelle disposition et style pour une meilleure lisibilité et un contenu bien contenu dans le cadre
  const margin = 12.0;
  const innerMargin = 12.0;
  const boxWidth = 210.0;
  const boxHeight = 110.0;
  const valueFont = 25.0;
  const unitFont = 15.0;
  const infoFont = 14.0;
  const reliabilityFont = 13.0;

  Color trendColor;
  String trendIcon;
  String trendLabel;

  switch (windTrend.trend) {
    case WindTrendDirection.veeringRight:
      trendColor = Colors.green.shade700;
      trendIcon = '↗';
      trendLabel = 'Bascule droite';
      break;
    case WindTrendDirection.backingLeft:
      trendColor = Colors.orange.shade700;
      trendIcon = '↙';
      trendLabel = 'Bascule gauche';
      break;
    case WindTrendDirection.irregular:
      trendColor = Colors.red.shade600;
      trendIcon = '≋';
      trendLabel = 'Irrégulier';
      break;
    case WindTrendDirection.neutral:
      trendColor = Colors.blue.shade600;
      trendIcon = '→';
      trendLabel = 'Stable';
      break;
  }

  final background = Paint()
    ..color = Colors.black.withOpacity(0.80)
    ..style = PaintingStyle.fill;

  final rect = RRect.fromRectAndRadius(
    Rect.fromLTWH(margin, margin, boxWidth, boxHeight),
    const Radius.circular(12),
  );
  canvas.drawRRect(rect, background);

  // Affichage vertical, aligné à gauche, marges internes équilibrées
  double y = margin + innerMargin;
  final x = margin + innerMargin;

  // Direction
  _drawText(canvas, '${windDirDeg.toStringAsFixed(0)}°', Offset(x, y), fontSize: valueFont, color: Colors.white);
  y += valueFont + 2;
  // Force
  _drawText(canvas, '${windSpeed.toStringAsFixed(1)} nds', Offset(x, y), fontSize: unitFont, color: Colors.white.withOpacity(0.92));
  y += unitFont + 7;
  // Tendance
  _drawText(canvas, '$trendIcon $trendLabel', Offset(x, y), fontSize: infoFont, color: trendColor.withOpacity(0.95));
  y += infoFont + 7;
  // Fiabilité
  final reliability = windTrend.isReliable ? '✓ Fiable' : '⚠ Peu fiable';
  final reliabilityColor = windTrend.isReliable ? Colors.green.shade400 : Colors.orange.shade400;
  _drawText(canvas, '$reliability (${windTrend.supportPoints}pts)', Offset(x, y), fontSize: reliabilityFont, color: reliabilityColor.withOpacity(0.95));
  }

  void _drawBoundsInfo(Canvas canvas, Size size) {
  final southWest = mercatorService.toGeographic(LocalPosition(x: view.minX, y: view.minY));
  final northEast = mercatorService.toGeographic(LocalPosition(x: view.maxX, y: view.maxY));

  final geoTxt = 'Géo: Lat:[${southWest.latitude.toStringAsFixed(4)}° ; ${northEast.latitude.toStringAsFixed(4)}°]  '
    'Lon:[${southWest.longitude.toStringAsFixed(4)}° ; ${northEast.longitude.toStringAsFixed(4)}°]';

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

class _RoleColors {
  const _RoleColors({required this.background, required this.border, required this.text});
  final Color background;
  final Color border;
  final Color text;
}
