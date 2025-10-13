import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/datasources/maps/providers/map_providers.dart';
import '../../../../data/datasources/maps/models/map_layer.dart';
import '../../../../data/datasources/maps/services/multi_layer_tile_service.dart';

import '../../charts/presentation/widgets/multi_layer_tile_painter.dart';
import '../../charts/providers/mercator_coordinate_system_provider.dart';
import '../../charts/providers/course_providers.dart';

class BaseTileLayer extends ConsumerWidget {
  const BaseTileLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeMap = ref.watch(activeMapProvider);
    final mercatorService = ref.watch(mercatorCoordinateSystemProvider);
    final courseState = ref.watch(courseProvider);
    final layersCfg = MapLayersConfig.defaultConfig;

    // Rien de sélectionné → fond neutre + HUD
    if (activeMap == null) {
      return Stack(
        children: [
          const SizedBox.expand(),
          _HudBanner(text: 'Aucune carte sélectionnée — ouvre le bouton "Cartes" à droite pour en choisir/télécharger.'),
        ],
      );
    }

    final storagePathAsync = ref.watch(mapStorageDirectoryProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        return storagePathAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          error: (e, _) => Center(child: Text('Erreur stockage cartes: $e')),
          data: (storagePath) {
            final mapPath = '$storagePath/${activeMap.id}';
            return FutureBuilder(
              future: MultiLayerTileService.preloadLayeredTiles(
                mapId: activeMap.id,
                mapPath: mapPath,
                config: layersCfg,
              ),
              builder: (context, snapshot) {
                // 1) Pendant le chargement
                if (!snapshot.hasData) {
                  return const Center(child: Text('Chargement tuiles locales...'));
                }

                var tiles = snapshot.data!;
                // 2) Fallback ONLINE si aucune tuile locale trouvée
                if (tiles.isEmpty) {
                  return FutureBuilder(
                    future: _loadOnlineAroundCourse(
                      mercatorService: mercatorService,
                      courseState: courseState,
                      config: layersCfg,
                    ),
                    builder: (context, snap2) {
                      if (!snap2.hasData) {
                        return const Center(child: Text('Aucune tuile locale.\nChargement en ligne...'));
                      }
                      tiles = snap2.data!;
                      if (tiles.isEmpty) {
                        return Stack(
                          children: const [
                            SizedBox.expand(),
                            _HudBanner(text: 'Impossible de charger des tuiles.\nVérifie la connexion ou télécharge une carte.'),
                          ],
                        );
                      }
                      return _paint(tiles, mercatorService, constraints, courseState, layersCfg,
                          banner: 'Online fallback — ${tiles.length} tuiles (z=15)');
                    },
                  );
                }

                // 3) Tuiles locales ok
                return _paint(tiles, mercatorService, constraints, courseState, layersCfg,
                    banner: 'Local: ${activeMap.name} — ${tiles.length} tuiles');
              },
            );
          },
        );
      },
    );
  }

  Widget _paint(
    List<LayeredTile> tiles,
    dynamic mercatorService,
    BoxConstraints constraints,
    dynamic courseState,
    MapLayersConfig cfg, {
    String? banner,
  }) {
    return Stack(
      children: [
        CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: MultiLayerTilePainter(
            tiles,
            mercatorService,
            constraints,
            courseState,
            cfg,
          ),
        ),
        if (banner != null) _HudBanner(text: banner),
      ],
    );
  }

  /// Génère une petite grille 3×3 de tuiles **en ligne** centrée sur le parcours (ou (0,0) par défaut).
  Future<List<LayeredTile>> _loadOnlineAroundCourse({
    required dynamic mercatorService, // MercatorCoordinateSystemService
    required dynamic courseState,     // CourseState
    required MapLayersConfig config,
  }) async {
    // Centre : si parcours dispo → centre des bouées; sinon (0,0)
    double lat = 0.0, lon = 0.0;
    if (courseState.buoys.isNotEmpty) {
      double minLat =  90, maxLat = -90, minLon =  180, maxLon = -180;
      for (final b in courseState.buoys) {
        minLat = math.min(minLat, b.position.latitude);
        maxLat = math.max(maxLat, b.position.latitude);
        minLon = math.min(minLon, b.position.longitude);
        maxLon = math.max(maxLon, b.position.longitude);
      }
      lat = (minLat + maxLat) / 2.0;
      lon = (minLon + maxLon) / 2.0;
    }

    const zoom = 15;
    // Conversion lon/lat → indices tuile OSM
    int lonToTileX(double lon, int z) => ((lon + 180.0) / 360.0 * (1 << z)).floor();
    int latToTileY(double lat, int z) {
      final latRad = lat * (math.pi / 180.0);
      return ((1.0 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) / 2.0 * (1 << z)).floor();
    }

    final cx = lonToTileX(lon, zoom);
    final cy = latToTileY(lat, zoom);

    final tiles = <LayeredTile>[];
    for (int dx = -1; dx <= 1; dx++) {
      for (int dy = -1; dy <= 1; dy++) {
        final x = cx + dx;
        final y = cy + dy;
        final t = await MultiLayerTileService.loadLayeredTile(
          x: x,
          y: y,
          zoom: zoom,
          config: config,
          localMapPath: null, // <-- force ONLINE
        );
        tiles.add(t);
      }
    }
    return tiles;
  }
}

class _HudBanner extends StatelessWidget {
  const _HudBanner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 8,
      top: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.55),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 11),
        ),
      ),
    );
  }
}
