/// Dialog pour télécharger une nouvelle carte marine.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/map_providers.dart';
import '../models/map_bounds.dart';
import '../models/map_tile_set.dart';

class MapDownloadDialog extends ConsumerStatefulWidget {
  const MapDownloadDialog({
    super.key,
    this.initialBounds,
  });

  final MapBounds? initialBounds;

  @override
  ConsumerState<MapDownloadDialog> createState() => _MapDownloadDialogState();
}

class _MapDownloadDialogState extends ConsumerState<MapDownloadDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  // Contrôleurs pour les coordonnées
  final _minLatController = TextEditingController();
  final _maxLatController = TextEditingController();
  final _minLonController = TextEditingController();
  final _maxLonController = TextEditingController();
  
  int _selectedZoomLevel = 15;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    
    // Pré-remplir avec les bounds du parcours si disponibles
    if (widget.initialBounds != null) {
      final bounds = widget.initialBounds!;
      _minLatController.text = bounds.minLatitude.toStringAsFixed(6);
      _maxLatController.text = bounds.maxLatitude.toStringAsFixed(6);
      _minLonController.text = bounds.minLongitude.toStringAsFixed(6);
      _maxLonController.text = bounds.maxLongitude.toStringAsFixed(6);
      _nameController.text = 'Carte Parcours ${DateTime.now().day}/${DateTime.now().month}';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _minLatController.dispose();
    _maxLatController.dispose();
    _minLonController.dispose();
    _maxLonController.dispose();
    super.dispose();
  }

  MapBounds? get _currentBounds {
    try {
      final minLat = double.parse(_minLatController.text);
      final maxLat = double.parse(_maxLatController.text);
      final minLon = double.parse(_minLonController.text);
      final maxLon = double.parse(_maxLonController.text);
      
      return MapBounds(
        minLatitude: minLat,
        maxLatitude: maxLat,
        minLongitude: minLon,
        maxLongitude: maxLon,
      );
    } catch (e) {
      return null;
    }
  }

  int get _estimatedTileCount {
    final bounds = _currentBounds;
    if (bounds == null) return 0;
    return MapTileSet.estimateTileCount(bounds, _selectedZoomLevel);
  }

  String get _estimatedSize {
    final bounds = _currentBounds;
    if (bounds == null) return 'Inconnue';
    
    final bytes = MapTileSet.estimateSizeBytes(bounds, _selectedZoomLevel);
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  Future<void> _downloadMap() async {
    if (!_formKey.currentState!.validate()) return;

    final bounds = _currentBounds;
    if (bounds == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Coordonnées invalides')),
      );
      return;
    }

    final config = MapDownloadConfig(
      bounds: bounds,
      zoomLevel: _selectedZoomLevel,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty 
        ? null 
        : _descriptionController.text.trim(),
    );

    // Valider la configuration
    final errors = config.validate();
    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${errors.first}')),
      );
      return;
    }

    setState(() => _isDownloading = true);

    try {
      await ref.read(mapManagerProvider.notifier).downloadMap(config);
      
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Téléchargement démarré!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  void _useCourseArea() {
    final bounds = ref.read(courseBoundsProvider);
    if (bounds != null) {
      _minLatController.text = bounds.minLatitude.toStringAsFixed(6);
      _maxLatController.text = bounds.maxLatitude.toStringAsFixed(6);
      _minLonController.text = bounds.minLongitude.toStringAsFixed(6);
      _maxLonController.text = bounds.maxLongitude.toStringAsFixed(6);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final courseBounds = ref.watch(courseBoundsProvider);
    
    return Dialog(
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ...existing code...
              ],
            ),
          ),
        ),
      ),
    );
  }
}