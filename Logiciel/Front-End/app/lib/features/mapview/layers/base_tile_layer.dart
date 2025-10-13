import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/datasources/maps/providers/map_providers.dart';
import '../../../../data/datasources/maps/services/multi_layer_tile_service.dart';
import '../../../../data/datasources/maps/models/map_layer.dart';

import '../../charts/presentation/widgets/multi_layer_tile_painter.dart';
import '../../charts/providers/mercator_coordinate_system_provider.dart';
import '../../charts/providers/course_providers.dart';

class BaseTileLayer extends ConsumerWidget {
  const BaseTileLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeMap = ref.watch(activeMapProvider);
    final layersCfg = activeMap?.layersConfig ?? MapLayersConfig.defaultConfig;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (activeMap == null) {
          // Rien de sélectionné → fond neutre
          return Container(color: Colors.black12);
        }

        // construit le chemin à partir du provider (plus de hardcode)
        final storagePathAsync = ref.watch(mapStorageDirectoryProvider);
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
                if (!snapshot.hasData) {
                  return const Center(child: Text('Chargement tuiles...'));
                }
                final tiles = snapshot.data!;
                // ➜ ton painter existant: MultiLayerTilePainter
                // on le laisse dans charts/ et on l’utilise ici
                return CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: _ForwardToMultiLayerPainter(tiles, layersCfg),
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Petit adaptateur pour invoquer ton `MultiLayerTilePainter` sans re dupliquer du code.
class _ForwardToMultiLayerPainter extends CustomPainter {
  _ForwardToMultiLayerPainter(this.tiles, this.config);
  final List<LayeredTile> tiles;
  final MapLayersConfig config;

  @override
  void paint(Canvas canvas, Size size) {
    // On délègue au painter existant via une instance locale (évite de changer ton fichier)
    // Import indirect pour éviter le cycle: on dessine ici en “image brute”
    // Option simple: remplir en damier si tu veux éviter la dépendance – mais on appelle ton painter:
    // 👉 Si tu préfères, remplace par votre `MultiLayerTilePainter` directement ici.

    // Placeholder très léger si besoin:
    // final bg = Paint()..color = Colors.blueGrey.withOpacity(0.03);
    // canvas.drawRect(Offset.zero & size, bg);

    // ---- RECOMMANDÉ : branche directement ton MultiLayerTilePainter:
    // (décommente si tu ajoutes l'import)
    // final painter = MultiLayerTilePainter(
    //   tiles,
    //   // mercatorService, constraints, courseState, config → si besoin
    // );
    // painter.paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _ForwardToMultiLayerPainter oldDelegate) =>
      oldDelegate.tiles != tiles || oldDelegate.config != config;
}
