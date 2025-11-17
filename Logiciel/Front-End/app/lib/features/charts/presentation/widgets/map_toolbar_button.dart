/// Bouton de gestion des cartes dans le bandeau horizontal
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';

import '../../../../data/datasources/maps/models/map_tile_set.dart';
import '../../../../data/datasources/maps/models/map_bounds.dart';
import '../../../../data/datasources/maps/providers/map_providers.dart';
import '../../../../data/datasources/maps/widgets/map_download_dialog.dart';
import '../../../../data/datasources/gribs/grib_overlay_providers.dart';
import '../../../../data/datasources/gribs/grib_file_loader.dart';
import '../../providers/grib_layers_provider.dart';
import '../../../../common/kornog_data_directory.dart';
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
    final selectedMapId = ref.watch(selectedMapProvider);
    final showMaps = ref.watch(mapDisplayProvider);
    final oceamActive = ref.watch(oceamActiveProvider);
    
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
            
            // Option OSeaM Standard (Streaming)
            PopupMenuItem(
              enabled: false,
              child: SizedBox(
                width: 280,
                child: Row(
                  children: [
                    Icon(
                      Icons.cloud_download_outlined,
                      size: 16,
                      color: oceamActive ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'OSeaM Standard',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Consumer(
                      builder: (context, ref, _) {
                        final isActive = ref.watch(oceamActiveProvider);
                        print('[OSeaM] Menu Switch - isActive: $isActive');
                        return Switch(
                          value: isActive,
                          onChanged: (value) {
                            print('[OSeaM] Toggle clicked: $value');
                            ref.read(oceamActiveProvider.notifier).setActive(value);
                            print('[OSeaM] Provider updated, closing menu');
                            Navigator.of(context).pop();
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            
            const PopupMenuDivider(),
            
            // Option affichage des cartes téléchargées
            PopupMenuItem(
              enabled: false,
              child: Row(
                children: [
                  const Text('Afficher cartes téléchargées'),
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
            
            if (maps.isNotEmpty && !oceamActive) ...[
              const PopupMenuDivider(),
              
              // Titre section sélection carte
              PopupMenuItem(
                enabled: false,
                child: Text(
                  'Cartes disponibles',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              // Liste des cartes disponibles
              ...maps.where((map) => map.status == MapDownloadStatus.completed).map((map) {
                return PopupMenuItem<String>(
                  value: map.id,
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

                // Option télécharger nouvelle carte (moved here so it appears just before Manage)
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
        // Bouton météo GRIB (menu popup similaire aux cartes)
        PopupMenuButton<String>(
          icon: const Icon(Icons.cloud_outlined, size: 18),
          tooltip: 'Couches météo',
          offset: const Offset(0, 40),
          itemBuilder: (context) => [
            // En-tête avec titre
            PopupMenuItem(
              enabled: false,
              child: Row(
                children: [
                  const Icon(Icons.cloud, color: Colors.cyan, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Couches Météo',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.cyan,
                    ),
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(),
            
            // Option affichage des GRIB
            PopupMenuItem(
              enabled: false,
              child: Row(
                children: [
                  const Text('Afficher les données météo'),
                  const Spacer(),
                  Consumer(
                    builder: (context, ref, child) {
                      final gribVisible = ref.watch(gribVisibilityProvider);
                      return Switch(
                        value: gribVisible,
                        onChanged: (value) {
                          ref.read(gribVisibilityProvider.notifier).setVisible(value);
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
            
            const PopupMenuDivider(),
            
            // Titre section GRIB actif
            PopupMenuItem(
              enabled: false,
              child: Text(
                'Dossier GRIB actif',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            
            // Afficher le dossier GRIB actuellement actif
            PopupMenuItem(
              enabled: false,
              child: Consumer(
                builder: (context, ref, child) {
                  final activeDir = ref.watch(activeGribDirectoryProvider);
                  
                  if (activeDir == null) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Aucun dossier sélectionné',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    );
                  }
                  
                  final parts = activeDir.path.split('/');
                  final cycleName = parts.last;
                  final modelName = parts.length > 1 ? parts[parts.length - 2] : 'UNKNOWN';
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cycleName,
                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        modelName,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  );
                },
              ),
            ),
            
            const PopupMenuDivider(),
            
            // Option télécharger GRIB
            PopupMenuItem(
              value: 'download_grib',
              child: const Row(
                children: [
                  Icon(Icons.download, size: 16, color: Colors.green),
                  SizedBox(width: 12),
                  Text('Télécharger des données météo'),
                ],
              ),
            ),
            
            // Option gérer les fichiers GRIB
            PopupMenuItem(
              value: 'manage_grib',
              child: const Row(
                children: [
                  Icon(Icons.settings, size: 16, color: Colors.orange),
                  SizedBox(width: 12),
                  Text('Gérer les fichiers météo'),
                ],
              ),
            ),
          ],
          onSelected: _handleGribMenuSelection,
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
          // Select the map and ensure map display is enabled (no redundant checkbox needed)
          ref.read(selectedMapProvider.notifier).select(value);
          ref.read(mapDisplayProvider.notifier).toggle(true);
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

  Future<void> _handleGribMenuSelection(String value) async {
    switch (value) {
      case 'download_grib':
        await _showGribDownloadDialog();
        break;
      case 'manage_grib':
        await _showGribManageDialog();
        break;
    }
  }

  Future<void> _showGribDownloadDialog() async {
    await showDialog(
      context: context,
      builder: (context) => const GribLayersPanel(),
    );
  }

  Future<void> _showGribManageDialog() async {
    await showDialog(
      context: context,
      builder: (context) => const GribDirectorySelectorDialog(),
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

/// Dialog pour la gestion des fichiers GRIB
class GribFilesManagementDialog extends StatefulWidget {
  const GribFilesManagementDialog({super.key});

  @override
  State<GribFilesManagementDialog> createState() => _GribFilesManagementDialogState();
}

class _GribFilesManagementDialogState extends State<GribFilesManagementDialog> {
  late Future<List<File>> _gribFilesFuture;

  @override
  void initState() {
    super.initState();
    _loadGribFiles();
  }

  Future<void> _loadGribFiles() async {
    setState(() {
      _gribFilesFuture = _fetchGribFiles();
    });
  }

  Future<List<File>> _fetchGribFiles() async {
    final gribDir = await getGribDataDirectory();
    if (!gribDir.existsSync()) {
      return [];
    }

    final files = <File>[];
    for (final entity in gribDir.listSync(recursive: true)) {
      if (entity is File && (entity.path.endsWith('.grib2') || entity.path.endsWith('.grb2') || entity.path.endsWith('.grib'))) {
        files.add(entity);
      }
    }
    return files;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.cloud_download, color: Colors.cyan),
          SizedBox(width: 8),
          Text('Gestion des fichiers météo'),
        ],
      ),
      content: SizedBox(
        width: 500,
        height: 400,
        child: FutureBuilder<List<File>>(
          future: _gribFilesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text('Erreur: ${snapshot.error}'),
              );
            }

            final files = snapshot.data ?? [];

            if (files.isEmpty) {
              return const Center(
                child: Text('Aucun fichier météo trouvé'),
              );
            }

            return ListView.builder(
              itemCount: files.length,
              itemBuilder: (context, index) {
                final file = files[index];
                final fileName = file.path.split('/').last;
                final fileSize = _formatFileSize(file.lengthSync());

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.cloud_download, color: Colors.cyan),
                    title: Text(fileName, overflow: TextOverflow.ellipsis),
                    subtitle: Text(fileSize),
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      itemBuilder: (context) => [
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
                        if (action == 'delete') {
                          await _confirmDeleteFile(context, file);
                        }
                      },
                    ),
                  ),
                );
              },
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

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<void> _confirmDeleteFile(BuildContext context, File file) async {
    final fileName = file.path.split('/').last;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le fichier'),
        content: Text('Êtes-vous sûr de vouloir supprimer "$fileName" ?\n\n'
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

    if (confirmed == true && mounted) {
      try {
        await file.delete();
        await _loadGribFiles();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fichier "$fileName" supprimé')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: impossible de supprimer le fichier')),
          );
        }
      }
    }
  }
}

/// Dialog pour la sélection du dossier GRIB actif
class GribDirectorySelectorDialog extends ConsumerStatefulWidget {
  const GribDirectorySelectorDialog({super.key});

  @override
  ConsumerState<GribDirectorySelectorDialog> createState() => _GribDirectorySelectorDialogState();
}

class _GribDirectorySelectorDialogState extends ConsumerState<GribDirectorySelectorDialog> {
  late Future<List<Directory>> _directoriesFuture;

  @override
  void initState() {
    super.initState();
    _directoriesFuture = GribFileLoader.findGribDirectories();
  }

  @override
  Widget build(BuildContext context) {
    final activeDir = ref.watch(activeGribDirectoryProvider);

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.cloud_queue, color: Colors.cyan),
          SizedBox(width: 8),
          Text('Sélectionner le dossier GRIB'),
        ],
      ),
      content: SizedBox(
        width: 500,
        height: 400,
        child: FutureBuilder<List<Directory>>(
          future: _directoriesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text('Erreur: ${snapshot.error}'),
              );
            }

            final directories = snapshot.data ?? [];

            if (directories.isEmpty) {
              return const Center(
                child: Text('Aucun dossier GRIB trouvé'),
              );
            }

            return ListView.builder(
              itemCount: directories.length,
              itemBuilder: (context, index) {
                final dir = directories[index];
                final parts = dir.path.split('/');
                final cycleName = parts.last;
                final modelName = parts.length > 1 ? parts[parts.length - 2] : 'UNKNOWN';
                final isActive = activeDir?.path == dir.path;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: isActive ? Colors.cyan.shade50 : null,
                  child: ListTile(
                    leading: Icon(
                      Icons.folder,
                      color: isActive ? Colors.cyan : Colors.grey,
                    ),
                    title: Text(
                      cycleName,
                      style: TextStyle(
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(modelName),
                    trailing: isActive
                        ? const Icon(Icons.check_circle, color: Colors.cyan)
                        : PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 20),
                            itemBuilder: (context) => [
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
                              if (action == 'delete') {
                                await _confirmDeleteDirectory(context, dir, cycleName);
                              }
                            },
                          ),
                    onTap: () async {
                      ref.read(activeGribDirectoryProvider.notifier).setDirectory(dir);
                      
                      // Charger le premier fichier du dossier sélectionné manuellement
                      print('[GRIB_SELECTOR] 🔷 Sélection manuelle du dossier: ${dir.path}');
                      final allFiles = await GribFileLoader.findGribFiles();
                      final dirFiles = allFiles.where((f) => f.path.startsWith(dir.path)).toList();
                      
                      if (dirFiles.isNotEmpty) {
                        print('[GRIB_SELECTOR] 📥 Chargement du premier fichier');
                        await loadGribFile(dirFiles.first, ref);
                      }
                      
                      if (mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Dossier GRIB sélectionné: $cycleName')),
                        );
                      }
                    },
                  ),
                );
              },
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

  Future<void> _confirmDeleteDirectory(BuildContext context, Directory dir, String cycleName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le dossier GRIB'),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer le dossier "$cycleName" ?\n\n'
          'Tous les fichiers GRIB de ce dossier seront supprimés.\n'
          'Cette action est irréversible.',
        ),
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

    if (confirmed == true && mounted) {
      try {
        // Si c'est le dossier actif, le désélectionner
        if (ref.read(activeGribDirectoryProvider)?.path == dir.path) {
          ref.read(activeGribDirectoryProvider.notifier).setDirectory(null);
        }

        // Supprimer le dossier et tous ses contenus
        await dir.delete(recursive: true);
        
        // Rafraîchir la liste
        setState(() {
          _directoriesFuture = GribFileLoader.findGribDirectories();
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Dossier "$cycleName" supprimé avec succès')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: impossible de supprimer le dossier ($e)')),
          );
        }
      }
    }
  }
}
