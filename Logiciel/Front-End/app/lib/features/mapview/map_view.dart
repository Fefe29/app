import 'package:flutter/widgets.dart';
import 'layers/base_tile_layer.dart';
import 'layers/grib_overlay_layer.dart';
import 'layers/vector_layer.dart';
import 'layers/interaction_layer.dart';

class MapView extends StatelessWidget {
  const MapView({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: const [
        BaseTileLayer(),     // Fond de carte
        GribOverlayLayer(),  // Overlay GRIB
        VectorLayer(),       // Bouées / lignes / route
        InteractionLayer(),  // Gestes
      ],
    );
  }
}

