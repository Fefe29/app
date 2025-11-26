/// Simple intégration OpenSeaMap avec flutter_map
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;
import '../../charts/domain/models/geographic_position.dart';
import '../../alarms/presentation/providers/anchor_visualization_provider.dart';

/// Widget OpenSeaMap simple avec flutter_map - INTÉGRÉ AU SYSTÈME DE VUE EXISTANT
class FlutterMapOSeaMSimple extends ConsumerStatefulWidget {
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
  ConsumerState<FlutterMapOSeaMSimple> createState() => _FlutterMapOSeaMSimpleState();
}

class _FlutterMapOSeaMSimpleState extends ConsumerState<FlutterMapOSeaMSimple> {
  late MapController mapController;

  @override
  void initState() {
    super.initState();
    mapController = MapController();
    // Sync initial après la première frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncMapWithView();
    });
  }

  @override
  void didUpdateWidget(FlutterMapOSeaMSimple oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Synchroniser à chaque fois que le widget parent reçoit des props différentes
    _syncMapWithView();
  }

  void _syncMapWithView() {
    try {
      if (widget.mercatorService == null || widget.view == null) {
        return;
      }

      // ✅ Calculer le centre RÉEL du viewport visible
      // Le centre du viewport en pixels est toujours au centre du canvas
      final centerPixelX = widget.canvasSize.width / 2;
      final centerPixelY = widget.canvasSize.height / 2;
      
      // Inverser en coordonnées Mercator locales
      final centerMercator = widget.view.unproject(centerPixelX, centerPixelY, widget.canvasSize);
      
      // Convertir en géographique
      final centerGeo = widget.mercatorService.toGeographic(
        LocalPosition(x: centerMercator.dx, y: centerMercator.dy),
      );

      // ✅ Calculer le zoom OSM directement depuis view.scale
      final baseZoom = 15.0; // Zoom quand _zoomFactor = 1.0
      final zoomAdjustment = math.log(widget.view.scale / 0.19277) / math.ln2;
      final zoom = (baseZoom + zoomAdjustment).clamp(1.0, 20.0);

      // Synchroniser la carte
      mapController.move(
        LatLng(centerGeo.latitude, centerGeo.longitude),
        zoom,
      );
    } catch (e) {
      // Silencieusement ignorer les erreurs
    }
  }

  List<Widget> _buildAnchorLayers(AnchorVisualization anchorViz) {
    if (!anchorViz.visible) {
      return [];
    }
    
    if (anchorViz.latitude == 0.0 && anchorViz.longitude == 0.0) {
      return [];
    }

    final anchorPoint = LatLng(anchorViz.latitude, anchorViz.longitude);

    return [
      // Cercle de la zone de mouillage
      CircleLayer(
        circles: [
          CircleMarker(
            point: anchorPoint,
            radius: anchorViz.radiusMeters, // Rayon en mètres
            useRadiusInMeter: true,
            color: anchorViz.triggered
                ? Colors.red.withOpacity(0.4)   // Rouge si déclenché (plus opaque)
                : Colors.blue.withOpacity(0.35),  // Bleu sinon (plus opaque)
            borderColor: anchorViz.triggered
                ? Colors.red.withOpacity(0.9)
                : Colors.blue.withOpacity(0.8),
            borderStrokeWidth: 3.0,  // Plus épais
          ),
        ],
      ),
      
      // Marqueur de l'ancre au centre
      MarkerLayer(
        markers: [
          Marker(
            point: anchorPoint,
            width: 50,
            height: 50,
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: () {
                print('⚓ Ancre tapée à: $anchorPoint');
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Cercle de fond blanc
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                        color: anchorViz.triggered ? Colors.red : Colors.blue,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.anchor,
                      color: anchorViz.triggered ? Colors.red : Colors.blue,
                      size: 28,
                    ),
                  ),
                  // Badge d'alerte si dérive
                  if (anchorViz.triggered)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red,
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                        padding: const EdgeInsets.all(2),
                        child: const Text(
                          '!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
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
    // ✅ Calculer le centre et le zoom du viewport AVANT de construire la carte
    final centerPixelX = widget.canvasSize.width / 2;
    final centerPixelY = widget.canvasSize.height / 2;
    final centerMercator = widget.view.unproject(centerPixelX, centerPixelY, widget.canvasSize);
    final centerGeo = widget.mercatorService.toGeographic(
      LocalPosition(x: centerMercator.dx, y: centerMercator.dy),
    );
    
    final baseZoom = 15.0;
    final zoomAdjustment = math.log(widget.view.scale / 0.19277) / math.ln2;
    final initialZoom = (baseZoom + zoomAdjustment).clamp(1.0, 20.0);

    // Récupérer les données de l'ancre
    final anchorViz = ref.watch(anchorVisualizationProvider);

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: LatLng(centerGeo.latitude, centerGeo.longitude),
        initialZoom: initialZoom,
        // IMPORTANT: Désactiver TOUTES les interactions utilisateur
        // La carte est entièrement contrôlée par le ViewTransform
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.none, // Aucune interaction (ni zoom, ni pan)
        ),
      ),
      children: [
        // Couche OSM (OpenStreetMap) - base
        TileLayer(
          urlTemplate: 'https://a.tile.openstreetmap.de/tiles/osmde/{z}/{x}/{y}.png',
          userAgentPackageName: 'kornog.app',
          maxZoom: 19.0,
        ),
        // Couche OpenSeaMap - données marines (bouées, phares, etc.)
        TileLayer(
          urlTemplate: 'https://tiles.openseamap.org/seamark/{z}/{x}/{y}.png',
          userAgentPackageName: 'kornog.app',
          maxZoom: 18.0,
        ),
        
        // 🔵 Layer de visualisation de l'ancre et zone de mouillage
        ..._buildAnchorLayers(anchorViz),
      ],
    );
  }
}

