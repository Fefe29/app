/// Geographic coordinate input dialog for buoys and lines
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/course.dart';
import '../../domain/models/geographic_position.dart';
import '../../providers/coordinate_system_provider.dart';
import '../../providers/course_providers.dart';

class GeographicBuoyDialog extends ConsumerStatefulWidget {
  const GeographicBuoyDialog({
    super.key,
    required this.role,
    this.existing,
  });

  final BuoyRole role;
  final Buoy? existing;

  @override
  ConsumerState<GeographicBuoyDialog> createState() => _GeographicBuoyDialogState();
}

class _GeographicBuoyDialogState extends ConsumerState<GeographicBuoyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _latController = TextEditingController();
  final _lonController = TextEditingController();
  final _passageController = TextEditingController();
  // Suppression des coordonnées locales X/Y

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final existing = widget.existing!;
      _latController.text = existing.position.latitude.toStringAsFixed(6);
      _lonController.text = existing.position.longitude.toStringAsFixed(6);
      _passageController.text = existing.passageOrder?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _latController.dispose();
    _lonController.dispose();
    _passageController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    // Utilise uniquement les coordonnées géographiques directement
    final lat = double.parse(_latController.text.replaceAll(',', '.'));
    final lon = double.parse(_lonController.text.replaceAll(',', '.'));
    final position = GeographicPosition(latitude: lat, longitude: lon);

    final passageOrder = _passageController.text.isEmpty 
        ? null 
        : int.tryParse(_passageController.text);

    if (widget.existing != null) {
      ref.read(courseProvider.notifier).updateBuoyGeographic(
        widget.existing!.id,
        position: position,
        passageOrder: passageOrder,
        role: widget.role,
      );
    } else {
      ref.read(courseProvider.notifier).addBuoyGeographic(
        position,
        passageOrder: passageOrder,
        role: widget.role,
      );
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final coordinateService = ref.watch(coordinateSystemProvider);
    final isRegular = widget.role == BuoyRole.regular;
    String title;
    switch (widget.role) {
      case BuoyRole.regular:
        title = widget.existing != null ? 'Modifier la bouée' : 'Nouvelle bouée';
        break;
      case BuoyRole.committee:
        title = widget.existing != null ? 'Modifier le comité' : 'Nouveau comité';
        break;
      case BuoyRole.target:
        title = widget.existing != null ? 'Modifier le viseur' : 'Nouveau viseur';
        break;
    }

    return AlertDialog(
      title: Row(
        children: [
          Icon(_getIconForRole(widget.role), size: 24),
          const SizedBox(width: 8),
          Text(title),
        ],
      ),
      content: SizedBox(
        width: 450,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Coordinate system info
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.map, size: 16, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Système: ${coordinateService.config.name} (${coordinateService.config.origin.toFormattedString()})',
                        style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Coordonnées géographiques :', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latController,
                      decoration: const InputDecoration(
                        labelText: 'Latitude (°)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.north),
                        helperText: 'Ex: 43.5432',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^-?[0-9]*\.?[0-9]*')),
                      ],
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Requis';
                        final lat = double.tryParse(value!.replaceAll(',', '.'));
                        if (lat == null) return 'Nombre invalide';
                        if (lat < -90 || lat > 90) return 'Doit être entre -90° et +90°';
                        return null;
                      },
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
                        helperText: 'Ex: 7.1234',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^-?[0-9]*\.?[0-9]*')),
                      ],
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Requis';
                        final lon = double.tryParse(value!.replaceAll(',', '.'));
                        if (lon == null) return 'Nombre invalide';
                        if (lon < -180 || lon > 180) return 'Doit être entre -180° et +180°';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              
              if (isRegular) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passageController,
                  decoration: const InputDecoration(
                    labelText: 'Ordre de passage (optionnel)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.numbers),
                    helperText: '1, 2, 3... ou vide',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    if (value?.isNotEmpty == true && int.tryParse(value!) == null) {
                      return 'Nombre entier uniquement';
                    }
                    return null;
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save, size: 18),
          label: Text(widget.existing != null ? 'Modifier' : 'Ajouter'),
        ),
      ],
    );
  }

  IconData _getIconForRole(BuoyRole role) {
    switch (role) {
      case BuoyRole.regular:
        return Icons.radio_button_unchecked;
      case BuoyRole.committee:
        return Icons.location_on;
      case BuoyRole.target:
        return Icons.visibility;
    }
  }
}