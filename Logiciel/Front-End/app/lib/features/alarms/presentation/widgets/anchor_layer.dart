/// Fournisseur de couches flutter_map pour afficher l'ancre et la zone de mouillage
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../providers/anchor_visualization_provider.dart';

/// Fonction pour générer les couches flutter_map pour l'ancre
List<Widget> buildAnchorLayers(AnchorVisualization anchorViz) {
  print('🎯 buildAnchorLayers() - visible: ${anchorViz.visible}, lat: ${anchorViz.latitude}, lon: ${anchorViz.longitude}, radius: ${anchorViz.radiusMeters}');
  
  if (!anchorViz.visible) {
    print('❌ Ancre non visible (visible=false)');
    return [];
  }
  
  if (anchorViz.latitude == 0.0 && anchorViz.longitude == 0.0) {
    print('❌ Position invalide (0, 0)');
    return [];
  }

  final anchorPoint = LatLng(anchorViz.latitude, anchorViz.longitude);
  print('✅ Affichage de l\'ancre à: $anchorPoint');

  return [
    // Cercle de la zone de mouillage
    CircleLayer(
      circles: [
        CircleMarker(
          point: anchorPoint,
          radius: anchorViz.radiusMeters, // Rayon en mètres
          useRadiusInMeter: true,
          color: anchorViz.triggered
              ? Colors.red.withOpacity(0.3)   // Rouge si déclenché
              : Colors.blue.withOpacity(0.2),  // Bleu sinon
          borderColor: anchorViz.triggered
              ? Colors.red.withOpacity(0.8)
              : Colors.blue.withOpacity(0.6),
          borderStrokeWidth: 2.0,
        ),
      ],
    ),
    
    // Marqueur de l'ancre au centre
    MarkerLayer(
      markers: [
        Marker(
          point: anchorPoint,
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: () {
              // Possibilité d'interagir avec l'ancre (déplacer, etc.)
              print('⚓ Ancre tapée à: $anchorPoint');
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icône d'ancre
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: anchorViz.triggered ? Colors.red : Colors.blue,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.anchor,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                // Info bulle avec le rayon
                if (anchorViz.triggered)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '⚠️ Dérive!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  ];
}

class AnchorLayer extends ConsumerWidget {
  const AnchorLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final anchorViz = ref.watch(anchorVisualizationProvider);
    return buildAnchorLayers(anchorViz) as Widget;
  }
}
