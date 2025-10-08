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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Titre
              Row(
                children: [
                  const Icon(Icons.map, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Text(
                    'Télécharger une carte',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Nom de la carte
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom de la carte *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value?.trim().isEmpty ?? true) {
                    return 'Le nom est obligatoire';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optionnel)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              
              const SizedBox(height: 20),
              
              // Zone géographique
              Row(
                children: [
                  const Text(
                    'Zone géographique',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  if (courseBounds != null)
                    TextButton.icon(
                      onPressed: _useCourseArea,
                      icon: const Icon(Icons.my_location, size: 16),
                      label: const Text('Utiliser le parcours'),
                    ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Coordonnées
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _minLatController,
                      decoration: const InputDecoration(
                        labelText: 'Latitude min *',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*')),
                      ],
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Obligatoire';
                        final val = double.tryParse(value!);
                        if (val == null || val < -90 || val > 90) {
                          return 'Latitude invalide';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _maxLatController,
                      decoration: const InputDecoration(
                        labelText: 'Latitude max *',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*')),
                      ],
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Obligatoire';
                        final val = double.tryParse(value!);
                        if (val == null || val < -90 || val > 90) {
                          return 'Latitude invalide';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _minLonController,
                      decoration: const InputDecoration(
                        labelText: 'Longitude min *',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*')),
                      ],
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Obligatoire';
                        final val = double.tryParse(value!);
                        if (val == null || val < -180 || val > 180) {
                          return 'Longitude invalide';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _maxLonController,
                      decoration: const InputDecoration(
                        labelText: 'Longitude max *',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*')),
                      ],
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Obligatoire';
                        final val = double.tryParse(value!);
                        if (val == null || val < -180 || val > 180) {
                          return 'Longitude invalide';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Niveau de zoom
              Row(
                children: [
                  const Text('Niveau de détail: '),
                  Expanded(
                    child: Slider(
                      value: _selectedZoomLevel.toDouble(),
                      min: 10,
                      max: 18,
                      divisions: 8,
                      label: _selectedZoomLevel.toString(),
                      onChanged: (value) {
                        setState(() => _selectedZoomLevel = value.round());
                      },
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text(
                      _selectedZoomLevel <= 12 
                        ? 'Aperçu'
                        : _selectedZoomLevel <= 15
                          ? 'Standard'
                          : 'Détaillé',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Informations sur la taille
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estimation du téléchargement:',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Tuiles: ${_estimatedTileCount}'),
                        Text('Taille: $_estimatedSize'),
                      ],
                    ),
                    if (_estimatedTileCount > 10000)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Icon(Icons.warning, color: Colors.orange, size: 16),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Zone importante, le téléchargement peut prendre du temps',
                                style: TextStyle(color: Colors.orange, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Boutons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isDownloading ? null : () => Navigator.of(context).pop(),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isDownloading ? null : _downloadMap,
                    child: _isDownloading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Télécharger'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}