import '../../providers/grib_layers_provider.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/datasources/gribs/grib_downloader.dart';
import '../../../../data/datasources/gribs/grib_download_controller.dart';
import '../../../../data/datasources/gribs/grib_overlay_providers.dart';
import '../../../../data/datasources/gribs/grib_file_loader.dart';
import '../../../../common/kornog_data_directory.dart';

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
    _selectedModel = GribModel.gfs025;
  }

  Future<void> _showGribManagerDialog() async {
    final gribDir = await getGribDataDirectory();

    // Lister les dossiers des modèles (GFS_0p25, GFS_0p50, etc.)
    final modelDirs = <Directory>[];
    if (gribDir.existsSync()) {
      modelDirs.addAll(gribDir.listSync().whereType<Directory>());
    }

    if (!mounted) return;

    // Premier dialogue: sélectionner le modèle
    final selectedModel = await showDialog<Directory>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sélectionner un modèle GRIB'),
        content: SizedBox(
          width: 400,
          height: 300, // Limiter la hauteur pour éviter l'overflow
          child: modelDirs.isEmpty
              ? const Text('Aucun modèle GRIB trouvé dans ~/.local/share/kornog/KornogData/grib/')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: modelDirs.length,
                  itemBuilder: (context, index) {
                    final modelDir = modelDirs[index];
                    final modelName = modelDir.path.split('/').last;
                    return ListTile(
                      title: Text(modelName),
                      subtitle: Text('${modelDir.listSync().length} dates disponibles'),
                      onTap: () => Navigator.pop(ctx, modelDir),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );

    if (selectedModel == null || !mounted) return;

    // Deuxième dialogue: sélectionner la date
    final cycleDirs = selectedModel.listSync().whereType<Directory>().toList()
      ..sort((a, b) => b.path.compareTo(a.path)); // Plus récent en premier

    final selectedCycle = await showDialog<Directory>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sélectionner une date'),
        content: SizedBox(
          width: 400,
          height: 300, // Limiter la hauteur
          child: cycleDirs.isEmpty
              ? const Text('Aucune date trouvée.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: cycleDirs.length,
                  itemBuilder: (context, index) {
                    final cycleDir = cycleDirs[index];
                    final cycleName = cycleDir.path.split('/').last;
                    final fileCount = cycleDir.listSync().whereType<File>().length;
                    return ListTile(
                      title: Text(cycleName),
                      subtitle: Text('$fileCount fichiers'),
                      onTap: () => Navigator.pop(ctx, cycleDir),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );

    if (selectedCycle == null || !mounted) return;

    // Troisième dialogue: sélectionner le fichier
    final files = selectedCycle.listSync().whereType<File>().where((f) {
      final path = f.path.toLowerCase();
      return path.endsWith('.anl') ||
          path.endsWith('.f000') ||
          path.endsWith('.f003') ||
          path.endsWith('.f006') ||
          path.endsWith('.f009') ||
          path.endsWith('.f012') ||
          path.endsWith('.f015') ||
          path.endsWith('.f018') ||
          path.endsWith('.f021') ||
          path.endsWith('.f024') ||
          path.contains('pgrb2');
    }).toList();

    final selectedFile = await showDialog<File>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sélectionner un fichier'),
        content: SizedBox(
          width: 400,
          height: 400, // Limiter la hauteur
          child: files.isEmpty
              ? const Text('Aucun fichier GRIB trouvé.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: files.length,
                  itemBuilder: (context, index) {
                    final file = files[index];
                    final fileName = file.path.split('/').last;
                    final fileSize = file.lengthSync();
                    return ListTile(
                      title: Text(fileName, style: const TextStyle(fontSize: 12)),
                      subtitle: Text('${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB'),
                      onTap: () => Navigator.pop(ctx, file),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );

    if (selectedFile == null) return;

    // Charger le fichier sélectionné
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chargement du GRIB...')),
      );

      final fileName = selectedFile.path.split('/').last;
      print('[GRIB_PANEL] Chargement de: $fileName');

      // Charger la grille
      final grid = await GribFileLoader.loadGridFromGribFile(selectedFile);
      if (grid != null) {
        final (vmin, vmax) = grid.getValueBounds();
        ref.read(currentGribGridProvider.notifier).setGrid(grid);
        ref.read(gribVminProvider.notifier).setVmin(vmin);
        ref.read(gribVmaxProvider.notifier).setVmax(vmax);
        
        // Stocker le dernier fichier chargé pour pouvoir accéder aux vecteurs
        ref.read(lastLoadedGribFileProvider.notifier).setFile(selectedFile);
        
        print('[GRIB_PANEL] ✅ Grid chargée: ${grid.nx}x${grid.ny}, values: $vmin..$vmax');
        print('[GRIB_PANEL] 💾 Dernier fichier stocké: ${selectedFile.path}');

        // Charger aussi les vecteurs U/V automatiquement
        print('[GRIB_PANEL] Chargement des vecteurs U/V...');
        final (uGrid, vGrid) = await GribFileLoader.loadWindVectorsFromGribFile(selectedFile);
        if (uGrid != null && vGrid != null) {
          ref.read(currentGribUGridProvider.notifier).setGrid(uGrid);
          ref.read(currentGribVGridProvider.notifier).setGrid(vGrid);
          print('[GRIB_PANEL] ✅ Vecteurs U/V chargés et stockés dans providers');
        } else {
          print('[GRIB_PANEL] ⚠️ Vecteurs U/V non chargés (null)');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('GRIB chargé: $fileName')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erreur: impossible de charger le GRIB')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedVars = _selected[_selectedModel] ?? <GribVariable>{};
    final dlState = ref.watch(gribDownloadControllerProvider);
    final isBusy = dlState.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Couches GRIB'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _showGribManagerDialog,
            tooltip: 'Gérer les fichiers GRIB',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // === SECTION: Contrôle temporel GRIB ===
              // NOTE: Le contrôle temporel a été déplacé en bas de la carte (GribTimeSliderWidget)
              // pour une meilleure intégration avec la visualisation en temps réel
              const SizedBox(height: 8),

              // Switch d'affichage des GRIBs (heatmap + flèches)
              Row(
                children: [
                  const Text('Afficher les GRIBs'),
                  const SizedBox(width: 8),
                  Switch(
                    value: ref.watch(gribVisibilityProvider),
                    onChanged: (v) => ref.read(gribVisibilityProvider.notifier).setVisible(v),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Téléchargement météo GRIB',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
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
                      title: Text(variable.name),
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
