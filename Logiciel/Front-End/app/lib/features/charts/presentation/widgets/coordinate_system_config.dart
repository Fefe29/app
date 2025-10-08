/// Geographic coordinate system configuration widget
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/coordinate_system_provider.dart';
import '../../domain/models/geographic_position.dart';

class CoordinateSystemConfigDialog extends ConsumerStatefulWidget {
  const CoordinateSystemConfigDialog({super.key});

  @override
  ConsumerState<CoordinateSystemConfigDialog> createState() => _CoordinateSystemConfigDialogState();
}

class _CoordinateSystemConfigDialogState extends ConsumerState<CoordinateSystemConfigDialog> {
  final _latController = TextEditingController();
  final _lonController = TextEditingController();
  final _nameController = TextEditingController();
  String _selectedPreset = 'mediterranean';

  @override
  void initState() {
    super.initState();
    final current = ref.read(coordinateSystemProvider);
    _latController.text = current.config.origin.latitude.toStringAsFixed(6);
    _lonController.text = current.config.origin.longitude.toStringAsFixed(6);
    _nameController.text = current.config.name;
  }

  @override
  void dispose() {
    _latController.dispose();
    _lonController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _applyPreset() {
    GeographicPosition origin;
    String name;

    switch (_selectedPreset) {
      case 'mediterranean':
        origin = CoordinateSystemPresets.mediterranean;
        name = 'Méditerranée';
        break;
      case 'english_channel':
        origin = CoordinateSystemPresets.englishChannel;
        name = 'Manche';
        break;
      case 'san_francisco':
        origin = CoordinateSystemPresets.sanFranciscoBay;
        name = 'San Francisco';
        break;
      case 'sydney':
        origin = CoordinateSystemPresets.sydneyHarbour;
        name = 'Sydney';
        break;
      default:
        return;
    }

    _latController.text = origin.latitude.toStringAsFixed(6);
    _lonController.text = origin.longitude.toStringAsFixed(6);
    _nameController.text = name;
  }

  void _saveConfiguration() {
    final lat = double.tryParse(_latController.text);
    final lon = double.tryParse(_lonController.text);

    if (lat == null || lon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Coordonnées invalides')),
      );
      return;
    }

    if (lat < -90 || lat > 90) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Latitude doit être entre -90° et +90°')),
      );
      return;
    }

    if (lon < -180 || lon > 180) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Longitude doit être entre -180° et +180°')),
      );
      return;
    }

    final origin = GeographicPosition(latitude: lat, longitude: lon);
    ref.read(coordinateSystemProvider.notifier).setOrigin(
      origin,
      name: _nameController.text.isNotEmpty ? _nameController.text : 'Personnalisé',
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.map, size: 24),
          SizedBox(width: 8),
          Text('Configuration des coordonnées'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choisissez un système de coordonnées pour vos parcours.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            
            // Preset selection
            const Text('Zones prédéfinies :', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedPreset,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(value: 'mediterranean', child: Text('Méditerranée (France)')),
                DropdownMenuItem(value: 'english_channel', child: Text('Manche (Portsmouth)')),
                DropdownMenuItem(value: 'san_francisco', child: Text('San Francisco (USA)')),
                DropdownMenuItem(value: 'sydney', child: Text('Sydney (Australie)')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedPreset = value!;
                });
              },
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _applyPreset,
              icon: const Icon(Icons.location_on, size: 16),
              label: const Text('Appliquer cette zone'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade50,
                foregroundColor: Colors.blue.shade700,
              ),
            ),
            
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            
            // Manual coordinate entry
            const Text('Coordonnées personnalisées :', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            
            // Name field
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nom de la zone',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label),
              ),
            ),
            const SizedBox(height: 12),
            
            // Coordinate fields
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _latController,
                    decoration: const InputDecoration(
                      labelText: 'Latitude (°)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.north),
                      helperText: '-90 à +90',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^-?[0-9]*\.?[0-9]*')),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _lonController,
                    decoration: const InputDecoration(
                      labelText: 'Longitude (°)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.east),
                      helperText: '-180 à +180',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^-?[0-9]*\.?[0-9]*')),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ces coordonnées serviront d\'origine pour convertir les positions en mètres.',
                      style: TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton.icon(
          onPressed: _saveConfiguration,
          icon: const Icon(Icons.save, size: 18),
          label: const Text('Enregistrer'),
        ),
      ],
    );
  }
}

/// Widget displaying current coordinate system info
class CoordinateSystemInfo extends ConsumerWidget {
  const CoordinateSystemInfo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coordSystem = ref.watch(coordinateSystemProvider);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.map, size: 14, color: Colors.blue.shade700),
          const SizedBox(width: 4),
          Text(
            coordSystem.config.name,
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '(${coordSystem.config.origin.latitude.toStringAsFixed(3)}°, ${coordSystem.config.origin.longitude.toStringAsFixed(3)}°)',
            style: TextStyle(
              fontSize: 11,
              color: Colors.blue.shade600,
            ),
          ),
        ],
      ),
    );
  }
}