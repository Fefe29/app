import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/datasources/gribs/grib_downloader.dart';
import '../../../../data/datasources/gribs/grib_download_controller.dart';

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
  double _leftLon = -12, _rightLon = 12, _bottomLat = 41, _topLat = 52;

  @override
  void initState() {
    super.initState();
    _selectedModel = GribModel.gfs025;
  }

  @override
  Widget build(BuildContext context) {
    final selectedVars = _selected[_selectedModel] ?? <GribVariable>{};
    final dlState = ref.watch(gribDownloadControllerProvider);
    final isBusy = dlState.isLoading;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Téléchargement météo GRIB',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            DropdownButtonFormField<GribModel>(
              value: _selectedModel,
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
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) => setState(() => _leftLon = double.tryParse(v) ?? _leftLon),
                    enabled: !isBusy,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: _rightLon.toString(),
                    decoration: const InputDecoration(labelText: 'Longitude Est'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) => setState(() => _rightLon = double.tryParse(v) ?? _rightLon),
                    enabled: !isBusy,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _bottomLat.toString(),
                    decoration: const InputDecoration(labelText: 'Latitude Sud'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) => setState(() => _bottomLat = double.tryParse(v) ?? _bottomLat),
                    enabled: !isBusy,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: _topLat.toString(),
                    decoration: const InputDecoration(labelText: 'Latitude Nord'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) => setState(() => _topLat = double.tryParse(v) ?? _topLat),
                    enabled: !isBusy,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Days
            Row(
              children: [
                const Text('Durée (jours):'),
                Expanded(
                  child: Slider(
                    value: _days.toDouble(),
                    min: 1,
                    max: 7,
                    divisions: 6,
                    label: '$_days',
                    onChanged: isBusy ? null : (v) => setState(() => _days = v.round()),
                  ),
                ),
                Text('$_days'),
              ],
            ),

            // Step
            Row(
              children: [
                const Text('Pas (h):'),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _stepHours,
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('1 h')),
                    DropdownMenuItem(value: 3, child: Text('3 h')),
                    DropdownMenuItem(value: 6, child: Text('6 h')),
                  ],
                  onChanged: isBusy ? null : (v) => setState(() => _stepHours = v ?? _stepHours),
                ),
              ],
            ),
            const SizedBox(height: 12),

            const Text('Variables à télécharger :'),
            Wrap(
              children: [
                for (final variable in GribVariable.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: FilterChip(
                      label: Text(variable.name),
                      selected: selectedVars.contains(variable),
                      onSelected: isBusy
                          ? null
                          : (selected) {
                              setState(() {
                                final set = _selected.putIfAbsent(_selectedModel!, () => <GribVariable>{});
                                if (selected) {
                                  set.add(variable);
                                } else {
                                  set.remove(variable);
                                }
                              });
                            },
                    ),
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
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_download),
                    label: Text(isBusy ? 'Téléchargement…' : 'Télécharger la sélection'),
                    onPressed: (selectedVars.isEmpty || _selectedModel == null || isBusy)
                        ? null
                        : () async {
                            await ref.read(gribDownloadControllerProvider.notifier).download(
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
                    Text('Derniers fichiers: ${dlState.lastFiles.length}', style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
