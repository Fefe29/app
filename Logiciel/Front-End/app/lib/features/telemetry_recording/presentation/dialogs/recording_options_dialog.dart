/// Dialog pour choisir les options d'enregistrement avant de démarrer
import 'package:flutter/material.dart';
import 'package:kornog/features/telemetry_recording/models/recording_options.dart';

class RecordingOptionsDialog extends StatefulWidget {
  final RecordingOptions initialOptions;

  const RecordingOptionsDialog({
    Key? key,
    this.initialOptions = const RecordingOptions(),
  }) : super(key: key);

  @override
  State<RecordingOptionsDialog> createState() => _RecordingOptionsDialogState();
}

class _RecordingOptionsDialogState extends State<RecordingOptionsDialog> {
  late RecordingOptions options;

  @override
  void initState() {
    super.initState();
    options = widget.initialOptions;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Titre
              Text(
                '⚙️ Options d\'enregistrement',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),

              // Description
              Text(
                'Sélectionnez quelles données enregistrer :',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 16),

              // Checkboxes
              _CheckboxTile(
                title: '📍 Position (GPS)',
                subtitle: 'Latitude, longitude, altitude',
                value: options.recordPosition,
                onChanged: (val) {
                  setState(() {
                    options = options.copyWith(recordPosition: val);
                  });
                },
              ),
              _CheckboxTile(
                title: '💨 Vent',
                subtitle: 'Direction et force du vent',
                value: options.recordWind,
                onChanged: (val) {
                  setState(() {
                    options = options.copyWith(recordWind: val);
                  });
                },
              ),
              _CheckboxTile(
                title: '🚤 Performance',
                subtitle: 'Vitesse, cap, direction',
                value: options.recordPerformance,
                onChanged: (val) {
                  setState(() {
                    options = options.copyWith(recordPerformance: val);
                  });
                },
              ),
              _CheckboxTile(
                title: '⚙️ Système',
                subtitle: 'Moteur, électrique, batterie',
                value: options.recordSystem,
                onChanged: (val) {
                  setState(() {
                    options = options.copyWith(recordSystem: val);
                  });
                },
              ),
              _CheckboxTile(
                title: '📊 Autres',
                subtitle: 'Météo, marées, autres données',
                value: options.recordOther,
                onChanged: (val) {
                  setState(() {
                    options = options.copyWith(recordOther: val);
                  });
                },
              ),
              const SizedBox(height: 20),

              // Profils rapides
              Text(
                'Profils rapides :',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _ProfileButton(
                      label: 'Minimal',
                      onPressed: () {
                        setState(() {
                          options = RecordingOptions.minimal();
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    _ProfileButton(
                      label: 'Tout',
                      onPressed: () {
                        setState(() {
                          options = RecordingOptions.all();
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    _ProfileButton(
                      label: 'Rien',
                      onPressed: () {
                        setState(() {
                          options = RecordingOptions.none();
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Résumé
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _buildSummary(),
              ),
              const SizedBox(height: 24),

              // Boutons d'action
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(options),
                    icon: const Icon(Icons.check),
                    label: const Text('Démarrer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummary() {
    final items = <String>[];
    if (options.recordPosition) items.add('📍 Position');
    if (options.recordWind) items.add('💨 Vent');
    if (options.recordPerformance) items.add('🚤 Performance');
    if (options.recordSystem) items.add('⚙️ Système');
    if (options.recordOther) items.add('📊 Autres');

    if (items.isEmpty) {
      return Text(
        '⚠️ Aucune donnée sélectionnée',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.orange[700],
        ),
      );
    }

    return Text(
      'Enregistrement : ${items.join(', ')}',
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}

class _CheckboxTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final Function(bool) onChanged;

  const _CheckboxTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: CheckboxListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        value: value,
        onChanged: (val) => onChanged(val ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        dense: true,
      ),
    );
  }
}

class _ProfileButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _ProfileButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(label),
    );
  }
}
