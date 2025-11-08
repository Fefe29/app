import '../../providers/grib_layers_provider.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/datasources/gribs/grib_downloader.dart';
import '../../../../data/datasources/gribs/grib_download_controller.dart';
import '../../../../data/datasources/gribs/grib_overlay_providers.dart';
import '../../../../data/datasources/gribs/grib_file_loader.dart';

class GribLayersPanel extends ConsumerStatefulWidget {
  const GribLayersPanel({super.key});

  @override
  ConsumerState<GribLayersPanel> createState() => _GribLayersPanelState();
}

class _GribLayersPanelState extends ConsumerState<GribLayersPanel> {
  final Map<GribModel, Set<GribVariable>> _selected = {};
  GribModel? _selectedModel;
  int _days = 3;
  int _stepHours = 3;
  // Méditerranée (France du sud): 5-9°E, 42-45°N
  double _leftLon = 5, _rightLon = 9, _bottomLat = 42, _topLat = 45;

  @override
  void initState() {
    super.initState();
    print('[GRIB_PANEL] 🚀 INIT - GribLayersPanel initState appelé');
    _selectedModel = GribModel.gfs025;
  }

  @override
  Widget build(BuildContext context) {
    print('[GRIB_PANEL] 🏗️ BUILD - GribLayersPanel est en train de se construire');
    
    final selectedVars = _selected[_selectedModel] ?? <GribVariable>{};
    final dlState = ref.watch(gribDownloadControllerProvider);
    final isBusy = dlState.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Couches GRIB'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // === SECTION: Dossier GRIB actif ===
              Consumer(
                builder: (context, ref, child) {
                  final activeDir = ref.watch(activeGribDirectoryProvider);
                  
                  if (activeDir != null) {
                    final parts = activeDir.path.split('/');
                    final cycleName = parts.last;
                    final modelName = parts.length > 1 ? parts[parts.length - 2] : 'UNKNOWN';
                    
                    return Card(
                      color: Colors.cyan.shade50,
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dossier GRIB actif',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              cycleName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              modelName,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  
                  return Card(
                    color: Colors.orange.shade50,
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange[700], size: 20),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Aucun dossier GRIB sélectionné. Allez dans "Gérer les fichiers météo" pour en sélectionner un.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              
              // === SECTION: Configuration du téléchargement ===
              const SizedBox(height: 16),
              DropdownButtonFormField<GribModel>(
                initialValue: _selectedModel,
                decoration: const InputDecoration(labelText: 'Modèle météo'),
                items: [
                  for (final model in GribModel.values)
                    DropdownMenuItem(
                      value: model,
                      child: Text(model.name),
                    ),
                ],
                onChanged: isBusy ? null : (m) => setState(() => _selectedModel = m),
              ),
              const SizedBox(height: 12),
              // BBox
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _leftLon.toString(),
                      decoration: const InputDecoration(labelText: 'Longitude Ouest'),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (v) =>
                          setState(() => _leftLon = double.tryParse(v) ?? _leftLon),
                      enabled: !isBusy,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue: _rightLon.toString(),
                      decoration: const InputDecoration(labelText: 'Longitude Est'),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (v) =>
                          setState(() => _rightLon = double.tryParse(v) ?? _rightLon),
                      enabled: !isBusy,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _bottomLat.toString(),
                      decoration: const InputDecoration(labelText: 'Latitude Sud'),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (v) =>
                          setState(() => _bottomLat = double.tryParse(v) ?? _bottomLat),
                      enabled: !isBusy,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue: _topLat.toString(),
                      decoration: const InputDecoration(labelText: 'Latitude Nord'),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (v) =>
                          setState(() => _topLat = double.tryParse(v) ?? _topLat),
                      enabled: !isBusy,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _days.toDouble(),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      label: 'Jours: $_days',
                      onChanged: isBusy ? null : (v) => setState(() => _days = v.round()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButton<int?>(
                      isExpanded: true,
                      value: _stepHours,
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('1h')),
                        DropdownMenuItem(value: 3, child: Text('3h')),
                        DropdownMenuItem(value: 6, child: Text('6h')),
                        DropdownMenuItem(value: 12, child: Text('12h')),
                      ],
                      onChanged: isBusy ? null : (v) => setState(() => _stepHours = v ?? _stepHours),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Variables', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Column(
                children: [
                  for (final variable in GribVariable.values)
                    CheckboxListTile(
                      title: Text(variable.displayName),
                      value: selectedVars.contains(variable),
                      onChanged: isBusy
                          ? null
                          : (selected) {
                              setState(() {
                                if (selected ?? false) {
                                  _selected
                                      .putIfAbsent(_selectedModel!, () => {})
                                      .add(variable);
                                } else {
                                  _selected[_selectedModel]?.remove(variable);
                                }
                              });
                            },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Center(
                child: Column(
                  children: [
                    ElevatedButton.icon(
                      icon: isBusy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_download),
                      label: Text(isBusy ? 'Téléchargement…' : 'Télécharger la sélection'),
                      onPressed: (selectedVars.isEmpty || _selectedModel == null || isBusy)
                          ? null
                          : () async {
                              await ref
                                  .read(gribDownloadControllerProvider.notifier)
                                  .download(
                                    model: _selectedModel!,
                                    variables: selectedVars,
                                    days: _days,
                                    stepHours: _stepHours,
                                    leftLon: _leftLon,
                                    rightLon: _rightLon,
                                    bottomLat: _bottomLat,
                                    topLat: _topLat,
                                  );
                              final msg = ref.read(gribDownloadControllerProvider).message;
                              if (mounted && msg != null) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                              }
                            },
                    ),
                    const SizedBox(height: 8),
                    if (dlState.lastFiles.isNotEmpty)
                      Text('Derniers fichiers: ${dlState.lastFiles.length}',
                          style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
