/// Bouton de gestion des cartes dans le bandeau horizontal
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/datasources/maps/models/map_tile_set.dart';
import '../../../../data/datasources/maps/models/map_bounds.dart';
import '../../../../data/datasources/maps/providers/map_providers.dart';
import '../../../../data/datasources/maps/widgets/map_download_dialog.dart';
import '../../../../data/datasources/gribs/grib_downloader.dart';
import 'grib_layers_panel.dart';

class MapToolbarButton extends ConsumerStatefulWidget {
  const MapToolbarButton({super.key});

  @override
  ConsumerState<MapToolbarButton> createState() => _MapToolbarButtonState();
}

class _MapToolbarButtonState extends ConsumerState<MapToolbarButton> {

  @override
  Widget build(BuildContext context) {
    final maps = ref.watch(mapManagerProvider);
    final courseBounds = ref.watch(courseBoundsProvider);
    final selectedMapId = ref.watch(selectedMapProvider);
    final showMaps = ref.watch(mapDisplayProvider);
    
    return Row(
      children: [
        // Bouton carte marine (menu popup)
        PopupMenuButton<String>(
          icon: const Icon(Icons.map_outlined, size: 16),
          tooltip: 'Gestion des cartes',
          offset: const Offset(0, 40),
          itemBuilder: (context) => [
            // En-tête avec titre
            PopupMenuItem(
              enabled: false,
              child: Row(
                children: [
                  const Icon(Icons.map, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Cartes Marines',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(),
            
            // Option télécharger nouvelle carte
            PopupMenuItem(
              value: 'download',
              child: const Row(
                children: [
                  Icon(Icons.download, size: 16, color: Colors.green),
                  SizedBox(width: 12),
                  Text('Télécharger une carte'),
                ],
              ),
            ),
            
            const PopupMenuDivider(),
            
            // Option affichage des cartes
            PopupMenuItem(
              enabled: false,
              child: Row(
                children: [
                  const Text('Afficher les cartes'),
                  const Spacer(),
                  Switch(
                    value: showMaps,
                    onChanged: (value) {
                      ref.read(mapDisplayProvider.notifier).toggle(value);
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
            
            if (maps.isNotEmpty) ...[
              const PopupMenuDivider(),
              
              // Titre section sélection carte
              PopupMenuItem(
                enabled: false,
                child: Text(
                  'Carte active',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              
              // Liste des cartes disponibles
              ...maps.where((map) => map.status == MapDownloadStatus.completed).map((map) {
                return CheckedPopupMenuItem<String>(
                  value: map.id,
                  checked: selectedMapId == map.id,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        map.name,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${map.formattedSize} • Zoom ${map.zoomLevel}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              }).toList(),
              
              if (maps.where((map) => map.status == MapDownloadStatus.completed).isNotEmpty) ...[
                const PopupMenuDivider(),
                
                // Option gérer les cartes
                PopupMenuItem(
                  value: 'manage',
                  child: const Row(
                    children: [
                      Icon(Icons.settings, size: 16, color: Colors.orange),
                      SizedBox(width: 12),
                      Text('Gérer les cartes'),
                    ],
                  ),
                ),
              ],
            ] else ...[
              // Message si aucune carte
              PopupMenuItem(
                enabled: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Aucune carte téléchargée',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ],
          onSelected: _handleMenuSelection,
        ),
        // Bouton météo GRIB à côté
        IconButton(
          icon: const Icon(Icons.cloud_outlined, size: 18),
          tooltip: 'Couches météo',
          onPressed: () {
            showModalBottomSheet(
              context: context,
              builder: (_) => const GribLayersPanel(),
            );
          },
        ),
      ],
    );
  }

  Future<void> _handleMenuSelection(String value) async {
    switch (value) {
      case 'download':
        await _showDownloadDialog();
        break;
      case 'manage':
        await _showManageDialog();
        break;
      default:
        // Sélection d'une carte
        final maps = ref.read(mapManagerProvider);
        final selectedMap = maps.firstWhere(
          (map) => map.id == value,
          orElse: () => maps.first,
        );
        if (selectedMap.status == MapDownloadStatus.completed) {
          ref.read(selectedMapProvider.notifier).select(value);
        }
        break;
    }
  }

  Future<void> _showDownloadDialog() async {
    final courseBounds = ref.read(courseBoundsProvider);
    
    await showDialog(
      context: context,
      builder: (context) => MapDownloadDialog(initialBounds: courseBounds),
    );
  }

  Future<void> _showManageDialog() async {
    final maps = ref.read(mapManagerProvider);
    
    await showDialog(
      context: context,
      builder: (context) => _MapManagementDialog(
        maps: maps.where((map) => map.status == MapDownloadStatus.completed).toList(),
        onDeleteMap: (mapId) async {
          await ref.read(mapManagerProvider.notifier).deleteMap(mapId);
          // Réinitialiser la sélection si la carte supprimée était sélectionnée
          if (ref.read(selectedMapProvider) == mapId) {
            ref.read(selectedMapProvider.notifier).select(null);
          }
        },
      ),
    );
  }
}

/// Dialog pour la gestion avancée des cartes
class _MapManagementDialog extends StatelessWidget {
  const _MapManagementDialog({
    required this.maps,
    required this.onDeleteMap,
  });

  final List<MapTileSet> maps;
  final Future<void> Function(String mapId) onDeleteMap;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.settings, color: Colors.orange),
          SizedBox(width: 8),
          Text('Gestion des cartes'),
        ],
      ),
      content: SizedBox(
        width: 400,
        height: 300,
        child: maps.isEmpty
            ? const Center(
                child: Text('Aucune carte à gérer'),
              )
            : ListView.builder(
                itemCount: maps.length,
                itemBuilder: (context, index) {
                  final map = maps[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.map, color: Colors.blue),
                      title: Text(map.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${map.formattedSize} • Zoom ${map.zoomLevel}'),
                          Text(
                            _formatBounds(map.bounds),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'info',
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline, size: 16),
                                SizedBox(width: 8),
                                Text('Informations'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: const Row(
                              children: [
                                Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Supprimer', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                        onSelected: (action) async {
                          switch (action) {
                            case 'info':
                              await _showMapInfo(context, map);
                              break;
                            case 'delete':
                              await _confirmDelete(context, map);
                              break;
                          }
                        },
                      ),
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
      ],
    );
  }

  String _formatBounds(MapBounds bounds) {
    return '${bounds.minLatitude.toStringAsFixed(3)}°N → ${bounds.maxLatitude.toStringAsFixed(3)}°N\n'
           '${bounds.minLongitude.toStringAsFixed(3)}°E → ${bounds.maxLongitude.toStringAsFixed(3)}°E';
  }

  Future<void> _showMapInfo(BuildContext context, MapTileSet map) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(map.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Zone géographique', _formatBounds(map.bounds)),
            const SizedBox(height: 8),
            _buildInfoRow('Niveau de zoom', map.zoomLevel.toString()),
            const SizedBox(height: 8),
            _buildInfoRow('Taille', map.formattedSize),
            const SizedBox(height: 8),
            if (map.tileCount != null)
              _buildInfoRow('Nombre de tuiles', map.tileCount.toString()),
            if (map.downloadedAt != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow('Téléchargé le', 
                '${map.downloadedAt!.day}/${map.downloadedAt!.month}/${map.downloadedAt!.year}'),
            ],
            if (map.description?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              _buildInfoRow('Description', map.description!),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(value),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, MapTileSet map) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la carte'),
        content: Text('Êtes-vous sûr de vouloir supprimer la carte "${map.name}" ?\n\n'
            'Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      Navigator.of(context).pop(); // Fermer le dialog de gestion
      await onDeleteMap(map.id);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Carte "${map.name}" supprimée')),
        );
      }
    }
  }
}