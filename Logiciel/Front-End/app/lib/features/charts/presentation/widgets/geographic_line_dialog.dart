/// Geographic line input dialog for start and finish lines
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/course.dart';
import '../../domain/models/geographic_position.dart';
import '../../providers/coordinate_system_provider.dart';
import '../../providers/course_providers.dart';

class GeographicLineDialog extends ConsumerStatefulWidget {
  const GeographicLineDialog({
    super.key,
    required this.lineType,
    this.existingLine,
  });

  final LineType lineType;
  final LineSegment? existingLine;

  @override
  ConsumerState<GeographicLineDialog> createState() => _GeographicLineDialogState();
}

class _GeographicLineDialogState extends ConsumerState<GeographicLineDialog> {
  final _formKey = GlobalKey<FormState>();
  final _lat1Controller = TextEditingController();
  final _lon1Controller = TextEditingController();
  final _lat2Controller = TextEditingController();
  final _lon2Controller = TextEditingController();
  bool _useLocalCoordinates = false;
  final _x1Controller = TextEditingController();
  final _y1Controller = TextEditingController();
  final _x2Controller = TextEditingController();
  final _y2Controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.existingLine != null) {
      final existing = widget.existingLine!;
      // Try to use geographic coordinates if available, otherwise convert from local
      if (existing.tempLocalP1 != null && existing.tempLocalP2 != null) {
        // Legacy format - convert to geographic for display
        final coordinateService = ref.read(coordinateSystemProvider);
        final p1Geo = coordinateService.toGeographic(existing.tempLocalP1!);
        final p2Geo = coordinateService.toGeographic(existing.tempLocalP2!);
        
        _lat1Controller.text = p1Geo.latitude.toStringAsFixed(6);
        _lon1Controller.text = p1Geo.longitude.toStringAsFixed(6);
        _lat2Controller.text = p2Geo.latitude.toStringAsFixed(6);
        _lon2Controller.text = p2Geo.longitude.toStringAsFixed(6);
        
        _x1Controller.text = existing.tempLocalP1!.x.toStringAsFixed(1);
        _y1Controller.text = existing.tempLocalP1!.y.toStringAsFixed(1);
        _x2Controller.text = existing.tempLocalP2!.x.toStringAsFixed(1);
        _y2Controller.text = existing.tempLocalP2!.y.toStringAsFixed(1);
      } else {
        // Geographic format
        _lat1Controller.text = existing.point1.latitude.toStringAsFixed(6);
        _lon1Controller.text = existing.point1.longitude.toStringAsFixed(6);
        _lat2Controller.text = existing.point2.latitude.toStringAsFixed(6);
        _lon2Controller.text = existing.point2.longitude.toStringAsFixed(6);
      }
    }
  }

  @override
  void dispose() {
    _lat1Controller.dispose();
    _lon1Controller.dispose();
    _lat2Controller.dispose();
    _lon2Controller.dispose();
    _x1Controller.dispose();
    _y1Controller.dispose();
    _x2Controller.dispose();
    _y2Controller.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final coordinateService = ref.read(coordinateSystemProvider);
    GeographicPosition point1, point2;

    if (_useLocalCoordinates) {
      // Convert from local to geographic
      final x1 = double.parse(_x1Controller.text.replaceAll(',', '.'));
      final y1 = double.parse(_y1Controller.text.replaceAll(',', '.'));
      final x2 = double.parse(_x2Controller.text.replaceAll(',', '.'));
      final y2 = double.parse(_y2Controller.text.replaceAll(',', '.'));
      
      point1 = coordinateService.toGeographic(LocalPosition(x: x1, y: y1));
      point2 = coordinateService.toGeographic(LocalPosition(x: x2, y: y2));
    } else {
      // Use geographic coordinates directly
      final lat1 = double.parse(_lat1Controller.text.replaceAll(',', '.'));
      final lon1 = double.parse(_lon1Controller.text.replaceAll(',', '.'));
      final lat2 = double.parse(_lat2Controller.text.replaceAll(',', '.'));
      final lon2 = double.parse(_lon2Controller.text.replaceAll(',', '.'));
      
      point1 = GeographicPosition(latitude: lat1, longitude: lon1);
      point2 = GeographicPosition(latitude: lat2, longitude: lon2);
    }

    // Use new geographic methods directly
    if (widget.lineType == LineType.start) {
      ref.read(courseProvider.notifier).setStartLineGeographic(point1, point2);
    } else {
      ref.read(courseProvider.notifier).setFinishLineGeographic(point1, point2);
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final coordinateService = ref.watch(coordinateSystemProvider);
    final title = widget.lineType == LineType.start ? 'Ligne de départ' : 'Ligne d\'arrivée';
    final isStart = widget.lineType == LineType.start;

    return AlertDialog(
      title: Row(
        children: [
          Icon(isStart ? Icons.play_arrow : Icons.flag, size: 24),
          const SizedBox(width: 8),
          Text(title),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
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
                
                Text(
                  isStart 
                    ? 'Définissez les deux extrémités de la ligne de départ :'
                    : 'Définissez les deux extrémités de la ligne d\'arrivée :',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                
                const SizedBox(height: 16),
                
                // Coordinate type switcher
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Géographiques (Lat/Lon)'),
                        selected: !_useLocalCoordinates,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _useLocalCoordinates = false);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Locales (X/Y mètres)'),
                        selected: _useLocalCoordinates,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _useLocalCoordinates = true);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Point 1 coordinates
                Text(
                  'Point 1 ${isStart ? "(Viseur)" : "(Marque 1)"}:',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                
                if (_useLocalCoordinates) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _x1Controller,
                          decoration: const InputDecoration(
                            labelText: 'X (mètres)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.east),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^-?[0-9]*\.?[0-9]*')),
                          ],
                          validator: (value) {
                            if (value?.isEmpty ?? true) return 'Requis';
                            if (double.tryParse(value!.replaceAll(',', '.')) == null) return 'Nombre invalide';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _y1Controller,
                          decoration: const InputDecoration(
                            labelText: 'Y (mètres)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.north),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^-?[0-9]*\.?[0-9]*')),
                          ],
                          validator: (value) {
                            if (value?.isEmpty ?? true) return 'Requis';
                            if (double.tryParse(value!.replaceAll(',', '.')) == null) return 'Nombre invalide';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _lat1Controller,
                          decoration: const InputDecoration(
                            labelText: 'Latitude (°)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.north),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^-?[0-9]*\.?[0-9]*')),
                          ],
                          validator: (value) {
                            if (value?.isEmpty ?? true) return 'Requis';
                            final lat = double.tryParse(value!.replaceAll(',', '.'));
                            if (lat == null) return 'Nombre invalide';
                            if (lat < -90 || lat > 90) return 'Entre -90° et +90°';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _lon1Controller,
                          decoration: const InputDecoration(
                            labelText: 'Longitude (°)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.east),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^-?[0-9]*\.?[0-9]*')),
                          ],
                          validator: (value) {
                            if (value?.isEmpty ?? true) return 'Requis';
                            final lon = double.tryParse(value!.replaceAll(',', '.'));
                            if (lon == null) return 'Nombre invalide';
                            if (lon < -180 || lon > 180) return 'Entre -180° et +180°';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ],
                
                const SizedBox(height: 16),
                
                // Point 2 coordinates
                Text(
                  'Point 2 ${isStart ? "(Comité)" : "(Marque 2)"}:',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                
                if (_useLocalCoordinates) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _x2Controller,
                          decoration: const InputDecoration(
                            labelText: 'X (mètres)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.east),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^-?[0-9]*\.?[0-9]*')),
                          ],
                          validator: (value) {
                            if (value?.isEmpty ?? true) return 'Requis';
                            if (double.tryParse(value!.replaceAll(',', '.')) == null) return 'Nombre invalide';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _y2Controller,
                          decoration: const InputDecoration(
                            labelText: 'Y (mètres)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.north),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^-?[0-9]*\.?[0-9]*')),
                          ],
                          validator: (value) {
                            if (value?.isEmpty ?? true) return 'Requis';
                            if (double.tryParse(value!.replaceAll(',', '.')) == null) return 'Nombre invalide';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _lat2Controller,
                          decoration: const InputDecoration(
                            labelText: 'Latitude (°)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.north),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^-?[0-9]*\.?[0-9]*')),
                          ],
                          validator: (value) {
                            if (value?.isEmpty ?? true) return 'Requis';
                            final lat = double.tryParse(value!.replaceAll(',', '.'));
                            if (lat == null) return 'Nombre invalide';
                            if (lat < -90 || lat > 90) return 'Entre -90° et +90°';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _lon2Controller,
                          decoration: const InputDecoration(
                            labelText: 'Longitude (°)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.east),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^-?[0-9]*\.?[0-9]*')),
                          ],
                          validator: (value) {
                            if (value?.isEmpty ?? true) return 'Requis';
                            final lon = double.tryParse(value!.replaceAll(',', '.'));
                            if (lon == null) return 'Nombre invalide';
                            if (lon < -180 || lon > 180) return 'Entre -180° et +180°';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ],
                
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.green.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isStart 
                            ? 'La ligne de départ sera tracée entre le viseur et le comité de course.'
                            : 'La ligne d\'arrivée sera tracée entre les deux points définis.',
                          style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
          label: const Text('Définir'),
        ),
      ],
    );
  }
}