import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/datasources/gribs/grib_downloader.dart';

class GribLayersPanel extends ConsumerWidget {
  const GribLayersPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: Remplacer par un vrai provider d'état si besoin
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Couches météo disponibles', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          for (final model in GribModel.values)
            ExpansionTile(
              title: Text(model.name),
              children: [
                Wrap(
                  children: [
                    for (final variable in GribVariable.values)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: FilterChip(
                          label: Text(variable.name),
                          selected: false, // TODO: lier à l'état
                          onSelected: (selected) {
                            // TODO: gérer la sélection
                          },
                        ),
                      ),
                  ],
                ),
              ],
            ),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.cloud_download),
              label: const Text('Télécharger la sélection'),
              onPressed: () {
                // TODO: déclencher le téléchargement
                Navigator.of(context).pop();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class MapToolbarButton extends ConsumerStatefulWidget {
  const MapToolbarButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Bouton carte marine (menu popup)
        PopupMenuButton<String>(
          icon: const Icon(Icons.map_outlined, size: 16),
          onSelected: (value) {
            // TODO: gérer le choix
          },
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
}