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
    // Pré-remplir avec les bounds du parcours si disponibles, sinon valeurs par défaut demandées
    if (widget.initialBounds != null) {
      final bounds = widget.initialBounds!;
      _minLatController.text = bounds.minLatitude.toStringAsFixed(6);
      _maxLatController.text = bounds.maxLatitude.toStringAsFixed(6);
      _minLonController.text = bounds.minLongitude.toStringAsFixed(6);
      _maxLonController.text = bounds.maxLongitude.toStringAsFixed(6);
      _nameController.text = 'Carte Parcours ${DateTime.now().day}/${DateTime.now().month}';
    } else {
      // Valeurs par défaut : lat 43.5-43.6, lon 6.95-7.15
      _minLatController.text = '43.500000';
      _maxLatController.text = '43.600000';
      _minLonController.text = '6.950000';
      _maxLonController.text = '7.150000';
      _nameController.text = 'Carte 43.5-43.6 / 6.95-7.15';
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
    
    final maxDialogHeight = MediaQuery.of(context).size.height * 0.85;
    final dialogWidth = MediaQuery.of(context).size.width < 600 ? MediaQuery.of(context).size.width * 0.95 : 500.0;
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: maxDialogHeight,
          minWidth: 300,
          maxWidth: dialogWidth,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Télécharger une carte', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Nom de la carte',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Nom requis' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _descriptionController,
                          decoration: const InputDecoration(
                            labelText: 'Description (optionnel)',
                            border: OutlineInputBorder(),
                          ),
                          minLines: 1,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _minLatController,
                                decoration: const InputDecoration(
                                  labelText: 'Min latitude',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.numberWithOptions(decimal: true, signed: true),
                                validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _maxLatController,
                                decoration: const InputDecoration(
                                  labelText: 'Max latitude',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.numberWithOptions(decimal: true, signed: true),
                                validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _minLonController,
                                decoration: const InputDecoration(
                                  labelText: 'Min longitude',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.numberWithOptions(decimal: true, signed: true),
                                validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _maxLonController,
                                decoration: const InputDecoration(
                                  labelText: 'Max longitude',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.numberWithOptions(decimal: true, signed: true),
                                validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                value: _selectedZoomLevel,
                                decoration: const InputDecoration(
                                  labelText: 'Niveau de zoom',
                                  border: OutlineInputBorder(),
                                ),
                                items: List.generate(19, (i) => i + 1)
                                    .map((z) => DropdownMenuItem(
                                          value: z,
                                          child: Text(z.toString()),
                                        ))
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null) setState(() => _selectedZoomLevel = v);
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: _useCourseArea,
                              icon: const Icon(Icons.map),
                              label: const Text('Parcours'),
                              style: ElevatedButton.styleFrom(minimumSize: const Size(80, 48)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Text('Tuiles estimées: $_estimatedTileCount'),
                            const SizedBox(width: 16),
                            Text('Taille: $_estimatedSize'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Annuler'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _isDownloading ? null : _downloadMap,
                        child: _isDownloading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Télécharger'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}