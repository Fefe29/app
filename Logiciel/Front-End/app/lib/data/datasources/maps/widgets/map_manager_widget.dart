/// Widget de gestion des cartes téléchargées
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/map_tile_set.dart';
import '../models/map_bounds.dart';
import '../providers/map_providers.dart';
import 'map_download_dialog.dart';

class MapManagerWidget extends ConsumerWidget {
  const MapManagerWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maps = ref.watch(mapManagerProvider);
    final courseBounds = ref.watch(courseBoundsProvider);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // En-tête avec bouton de téléchargement
        Row(
          children: [
            const Icon(Icons.map, color: Colors.blue),
            const SizedBox(width: 8),
            const Text(
              'Cartes Marines',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => _showDownloadDialog(context, courseBounds),
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Télécharger'),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Liste des cartes ou message vide
        if (maps.isEmpty)
          _buildEmptyState(context, courseBounds)
        else
          _buildMapsList(context, ref, maps),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, MapBounds? courseBounds) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(
            Icons.map_outlined,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 12),
          Text(
            'Aucune carte téléchargée',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Téléchargez des cartes OpenStreetMap pour afficher le contexte géographique de vos parcours',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 16),
          if (courseBounds != null) ...[
            Text(
              'Zone du parcours actuel détectée',
              style: TextStyle(
                color: Colors.blue[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _showDownloadDialog(context, courseBounds),
              child: const Text('Télécharger la carte du parcours'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMapsList(BuildContext context, WidgetRef ref, List<MapTileSet> maps) {
    return Column(
      children: maps.map((map) => _buildMapCard(context, ref, map)).toList(),
    );
  }

  Widget _buildMapCard(BuildContext context, WidgetRef ref, MapTileSet map) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête avec nom et statut
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        map.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (map.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          map.description!,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _buildStatusChip(map.status),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Informations détaillées
            Row(
              children: [
                Expanded(
                  child: _buildInfoColumn('Zone', _formatBounds(map.bounds)),
                ),
                Expanded(
                  child: _buildInfoColumn('Zoom', 'Niveau ${map.zoomLevel}'),
                ),
                Expanded(
                  child: _buildInfoColumn('Taille', map.formattedSize),
                ),
              ],
            ),
            
            // Barre de progression pour les téléchargements en cours
            if (map.status == MapDownloadStatus.downloading) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: map.downloadProgress,
                      backgroundColor: Colors.grey[300],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    map.formattedProgress,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ],
            
            // Actions
            if (map.status != MapDownloadStatus.downloading) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Vérifier si elle couvre le parcours
                  if (ref.watch(courseBoundsProvider) != null)
                    Consumer(
                      builder: (context, ref, child) {
                        final coversCourse = ref.watch(mapCoversCourseProvider(map.id));
                        if (coversCourse) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle, size: 16, color: Colors.green[700]),
                                const SizedBox(width: 4),
                                Text(
                                  'Couvre le parcours',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green[700],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _deleteMap(context, ref, map),
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Supprimer'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red[600],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(MapDownloadStatus status) {
    Color color;
    String label;
    IconData icon;
    
    switch (status) {
      case MapDownloadStatus.completed:
        color = Colors.green;
        label = 'Terminé';
        icon = Icons.check_circle;
        break;
      case MapDownloadStatus.downloading:
        color = Colors.blue;
        label = 'En cours';
        icon = Icons.download;
        break;
      case MapDownloadStatus.failed:
        color = Colors.red;
        label = 'Échec';
        icon = Icons.error;
        break;
      case MapDownloadStatus.cancelled:
        color = Colors.grey;
        label = 'Annulé';
        icon = Icons.cancel;
        break;
      case MapDownloadStatus.notStarted:
        color = Colors.grey;
        label = 'En attente';
        icon = Icons.schedule;
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  String _formatBounds(MapBounds bounds) {
    return '${bounds.widthDegrees.toStringAsFixed(3)}° × ${bounds.heightDegrees.toStringAsFixed(3)}°';
  }

  void _showDownloadDialog(BuildContext context, MapBounds? courseBounds) {
    showDialog(
      context: context,
      builder: (context) => MapDownloadDialog(initialBounds: courseBounds),
    );
  }

  Future<void> _deleteMap(BuildContext context, WidgetRef ref, MapTileSet map) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la carte'),
        content: Text('Êtes-vous sûr de vouloir supprimer "${map.name}" ?\n\nCette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(mapManagerProvider.notifier).deleteMap(map.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Carte supprimée')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e')),
          );
        }
      }
    }
  }
}