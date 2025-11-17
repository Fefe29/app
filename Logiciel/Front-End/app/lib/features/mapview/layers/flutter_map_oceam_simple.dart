/// Simple intégration OpenSeaMap avec flutter_map
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;
import '../../charts/domain/models/geographic_position.dart';

/// Widget OpenSeaMap simple avec flutter_map - INTÉGRÉ AU SYSTÈME DE VUE EXISTANT
class FlutterMapOSeaMSimple extends StatefulWidget {
  final double initialLatitude;
  final double initialLongitude;
  final double initialZoom;
  final Size canvasSize;
  final dynamic mercatorService; // MercatorCoordinateSystemService
  final dynamic view; // ViewTransform

  const FlutterMapOSeaMSimple({
    super.key,
    this.initialLatitude = 48.37,
    this.initialLongitude = -4.49,
    this.initialZoom = 11,
    required this.canvasSize,
    required this.mercatorService,
    required this.view,
  });

  @override
  State<FlutterMapOSeaMSimple> createState() => _FlutterMapOSeaMSimpleState();
}

class _FlutterMapOSeaMSimpleState extends State<FlutterMapOSeaMSimple> {
  late MapController mapController;

  @override
  void initState() {
    super.initState();
    mapController = MapController();
  }

  @override
  void didUpdateWidget(FlutterMapOSeaMSimple oldWidget) {
    super.didUpdateWidget(oldWidget);
    print('[OSM] didUpdateWidget called');
    print('[OSM]   oldView: scale=${oldWidget.view?.scale}, offset=(${oldWidget.view?.offsetX}, ${oldWidget.view?.offsetY})');
    print('[OSM]   newView: scale=${widget.view?.scale}, offset=(${widget.view?.offsetX}, ${widget.view?.offsetY})');
    // Synchroniser la position et le zoom avec le ViewTransform
    _syncMapWithView();
  }

  void _syncMapWithView() {
    try {
      if (widget.mercatorService == null || widget.view == null) {
        print('[OSM] _syncMapWithView: mercatorService ou view null');
        return;
      }

      // Calculer le centre depuis les bounds du viewport
      final centerLocalX = (widget.view.minX + widget.view.maxX) / 2;
      final centerLocalY = (widget.view.minY + widget.view.maxY) / 2;

      // Convertir du système Mercator local au géographique
      final centerGeo = widget.mercatorService.toGeographic(
        LocalPosition(x: centerLocalX, y: centerLocalY),
      );

      // ✅ CLEF: Calculer l'empan VISIBLE du viewport, pas l'empan du parcours
      // L'empan visible dépend de: view.scale et canvas size
      // Plus view.scale est grand, plus l'empan visible est petit (on est zoom in)
      
      // Empan du parcours (bounds totaux)
      final parcourSpanX = widget.view.maxX - widget.view.minX;
      final parcourSpanY = widget.view.maxY - widget.view.minY;
      
      // Empan VISIBLE du viewport (après application de scale)
      // Au zoom initial (_zoomFactor=1.0), on voit tout le parcours
      // Au zoom higher (_zoomFactor>1.0), on voit un plus petit empan
      final visibleSpanX = parcourSpanX / widget.view.scale;
      final visibleSpanY = parcourSpanY / widget.view.scale;
      final visibleSpan = math.max(visibleSpanX, visibleSpanY);
      
      // Estimer le zoom basé sur cet empan visible
      double zoom = 15.0;
      if (visibleSpan < 500) zoom = 19.0;
      else if (visibleSpan < 1000) zoom = 18.0;
      else if (visibleSpan < 2000) zoom = 17.0;
      else if (visibleSpan < 5000) zoom = 16.0;
      else if (visibleSpan < 10000) zoom = 15.0;
      else if (visibleSpan < 25000) zoom = 14.0;
      else if (visibleSpan < 50000) zoom = 13.0;
      else if (visibleSpan < 100000) zoom = 12.0;
      else if (visibleSpan < 250000) zoom = 11.0;
      else if (visibleSpan < 500000) zoom = 10.0;
      else zoom = 9.0;

      // Debug: log la synchronisation
      print('[OSM] _syncMapWithView:');
      print('[OSM]   center=(${centerGeo.latitude.toStringAsFixed(4)}, ${centerGeo.longitude.toStringAsFixed(4)})');
      print('[OSM]   zoom=$zoom (scale=${widget.view.scale.toStringAsFixed(4)}, visibleSpan=$visibleSpan)');
      print('[OSM]   mapController moving to: (${centerGeo.latitude}, ${centerGeo.longitude}) @ zoom $zoom');

      // Synchroniser la carte avec la position du parcours
      mapController.move(
        LatLng(centerGeo.latitude, centerGeo.longitude),
        zoom,
      );
      
      print('[OSM]   move() called');
    } catch (e) {
      print('[OSM] Erreur _syncMapWithView: $e');
    }
  }

  double _estimateZoomFromSpan(double spanX, double spanY, Size canvasSize) {
    // Utiliser le scale du ViewTransform pour estimer le zoom
    // Plus le scale est grand, plus le zoom est élevé
    // Heuristique: zoom = 10 + log2(scale)
    
    final avgSpan = (spanX + spanY) / 2;
    final maxDimension = math.max(canvasSize.width, canvasSize.height);
    
    // Si l'empan est très petit, zoom très élevé
    if (avgSpan < 500) return 18;
    if (avgSpan < 1000) return 17;
    if (avgSpan < 2000) return 16;
    if (avgSpan < 5000) return 15;
    if (avgSpan < 10000) return 14;
    if (avgSpan < 25000) return 13;
    if (avgSpan < 50000) return 12;
    if (avgSpan < 100000) return 11;
    if (avgSpan < 250000) return 10;
    if (avgSpan < 500000) return 9;
    if (avgSpan < 1000000) return 8;
    return 7;
  }

  @override
  void dispose() {
    mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('[OSM] build() called, view.scale=${widget.view?.scale}');
    _syncMapWithView();

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: LatLng(widget.initialLatitude, widget.initialLongitude),
        initialZoom: widget.initialZoom,
        // IMPORTANT: Désactiver TOUTES les interactions utilisateur
        // La carte est entièrement contrôlée par le ViewTransform
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.none, // Aucune interaction (ni zoom, ni pan)
        ),
      ),
      children: [
        // Couche OSM (OpenStreetMap)
        TileLayer(
          urlTemplate: 'https://a.tile.openstreetmap.de/tiles/osmde/{z}/{x}/{y}.png',
          userAgentPackageName: 'kornog.app',
          maxZoom: 19.0,
        ),
        // Couche OpenSeaMap (marine features)
        TileLayer(
          urlTemplate: 'https://tiles.openstreetmap.fr/osmfr/{z}/{x}/{y}.png',
          userAgentPackageName: 'kornog.app',
          maxZoom: 20.0,
        ),
      ],
    );
  }
}

