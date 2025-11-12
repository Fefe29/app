/// Widget d'affichage des trames NMEA en temps réel
/// 
/// Affiche les 50 dernières trames reçues avec:
/// - Timestamp
/// - Type de sentence (RMC, VWT, etc.)
/// - Statut (✅ valide ou ❌ erreur)
/// - Icône de couleur selon le type

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kornog/common/providers/nmea_stream_provider.dart';

class NmeaSnifferWidget extends ConsumerWidget {
  const NmeaSnifferWidget({Key? key}) : super(key: key);

  /// Extraire le type de sentence (ex: "RMC" de "$GPRMC...")
  String _getSentenceType(String raw) {
    try {
      if (raw.isEmpty) return '?';
      // Format: $xxTYPE,... où TYPE est 3 caractères
      final match = RegExp(r'\$[A-Z]{2}([A-Z]{3})').firstMatch(raw);
      if (match != null) {
        return match.group(1) ?? '?';
      }
      return raw.substring(0, 6).toUpperCase();
    } catch (_) {
      return '?';
    }
  }

  /// Couleur selon le type de sentence
  Color _getTypeColor(String type) {
    switch (type) {
      case 'RMC':
        return Colors.blue;
      case 'VWT':
        return Colors.purple;
      case 'MWV':
        return Colors.orange;
      case 'DPT':
        return Colors.cyan;
      case 'MTW':
        return Colors.lightBlue;
      case 'HDT':
        return Colors.green;
      case 'VHW':
        return Colors.teal;
      case 'GLL':
        return Colors.deepPurple;
      default:
        return Colors.grey;
    }
  }

  /// Icône selon le type
  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'RMC':
        return Icons.location_on;
      case 'VWT':
        return Icons.air;
      case 'MWV':
        return Icons.wind_power;
      case 'DPT':
        return Icons.water;
      case 'MTW':
        return Icons.opacity;
      case 'HDT':
        return Icons.compass_calibration;
      case 'VHW':
        return Icons.waves;
      case 'GLL':
        return Icons.map;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sentences = ref.watch(nmeaSentencesProvider);
    // ignore: avoid_print
    print('🖼️ NmeaSnifferWidget rebuild: ${sentences.length} trames visibles');

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Trames NMEA en direct',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Chip(
                label: Text('${sentences.length}/50'),
                backgroundColor: sentences.isEmpty ? Colors.grey : Colors.green,
              ),
            ],
          ),
        ),
        // Liste des trames
        Expanded(
          child: sentences.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.radio_button_unchecked,
                          size: 40, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text(
                        'En attente de trames NMEA...',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  reverse: true, // Afficher les plus récentes en haut
                  itemCount: sentences.length,
                  itemBuilder: (context, index) {
                    final sentence = sentences[index];
                    final type = _getSentenceType(sentence.raw);
                    final typeColor = _getTypeColor(type);
                    final typeIcon = _getTypeIcon(type);

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: sentence.isValid
                            ? Colors.green[50]
                            : Colors.red[50],
                        border: Border.all(
                          color: sentence.isValid
                              ? Colors.green[300]!
                              : Colors.red[300]!,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header: Timestamp + Type + Status
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: typeColor.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Icon(
                                        typeIcon,
                                        size: 16,
                                        color: typeColor,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      type,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: typeColor,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatTime(sentence.timestamp),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                                Icon(
                                  sentence.isValid
                                      ? Icons.check_circle_outline
                                      : Icons.error_outline,
                                  size: 16,
                                  color: sentence.isValid
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // Trame NMEA
                            SelectableText(
                              sentence.raw,
                              style: TextStyle(
                                fontFamily: 'Courier',
                                fontSize: 11,
                                color: Colors.grey[800],
                              ),
                            ),
                            // Message d'erreur si présent
                            if (!sentence.isValid && sentence.errorMessage != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '❌ ${sentence.errorMessage}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.red,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        // Footer avec bouton clear
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(8),
              bottomRight: Radius.circular(8),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () {
                  ref.read(nmeaSentencesProvider.notifier).clear();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Historique effacé')),
                  );
                },
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Effacer'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Formater le timestamp
  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}.${(dt.millisecond ~/ 100).toString()}';
  }
}
