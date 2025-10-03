/// Drawer for configuring analysis filters.
/// See ARCHITECTURE_DOCS.md (section: analysis_filter_drawer.dart).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Import corrigé vers le provider (fichier déplacé dans providers/analysis_filters.dart)
import '../../providers/analysis_filters.dart';

class AnalysisFilterDrawer extends ConsumerWidget {
  const AnalysisFilterDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(analysisFiltersProvider);
    final setFilters = ref.read(analysisFiltersProvider.notifier);

    void update(AnalysisFilters next) => setFilters.state = next;

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text(
                'Données d\'Analyse',
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: const Text(
                'Sélectionnez les métriques à afficher',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(),
            
            // Section Vent
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.air, size: 20, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Métriques de Vent',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            
            SwitchListTile(
              value: filters.twd,
              onChanged: (v) => update(filters.copyWith(twd: v)),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.explore, size: 20, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Direction du Vent (TWD)',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              subtitle: const Text(
                'Direction absolue du vent vraie • 0-360°',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            
            SwitchListTile(
              value: filters.twa,
              onChanged: (v) => update(filters.copyWith(twa: v)),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.navigation, size: 20, color: Colors.red),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Angle au Vent (TWA)',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              subtitle: const Text(
                'Angle relatif au bateau • -180 à +180°',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            
            SwitchListTile(
              value: filters.tws,
              onChanged: (v) => update(filters.copyWith(tws: v)),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.air, size: 20, color: Colors.green),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Vitesse du Vent (TWS)',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              subtitle: const Text(
                'Vitesse du vent vraie • nœuds',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            
            const Divider(),
            
            // Section Autres métriques
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.show_chart, size: 20, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Autres Métriques',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            SwitchListTile(
              value: filters.boatSpeed,
              onChanged: (v) => update(filters.copyWith(boatSpeed: v)),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.speed, size: 20, color: Colors.purple),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Vitesse du Bateau',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              subtitle: const Text(
                'Vitesse sol et vitesse surface • nœuds',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SwitchListTile(
              value: filters.polars,
              onChanged: (v) => update(filters.copyWith(polars: v)),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.radar, size: 20, color: Colors.teal),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Polaires',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              subtitle: const Text(
                'Courbes de performance du bateau',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 16),
            
            // Résumé des sélections
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.blue),
                      SizedBox(width: 6),
                      Text(
                        'Métriques sélectionnées:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getSelectedMetricsSummary(filters),
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        update(const AnalysisFilters()); // Tout décocher
                      },
                      icon: const Icon(Icons.clear_all),
                      label: const Text('Tout effacer'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Appliquer'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getSelectedMetricsSummary(AnalysisFilters filters) {
    final selected = <String>[];
    if (filters.twd) selected.add('TWD (Direction)');
    if (filters.twa) selected.add('TWA (Angle)');
    if (filters.tws) selected.add('TWS (Vitesse)');
    if (filters.boatSpeed) selected.add('Vitesse bateau');
    if (filters.polars) selected.add('Polaires');
    
    if (selected.isEmpty) {
      return 'Aucune métrique sélectionnée';
    }
    
    if (selected.length == 1) {
      return selected.first;
    }
    
    return '${selected.length} métriques: ${selected.take(2).join(', ')}${selected.length > 2 ? '...' : ''}';
  }
}
