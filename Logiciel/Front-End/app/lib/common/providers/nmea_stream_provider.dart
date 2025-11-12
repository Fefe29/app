/// Provider pour streamer les trames NMEA en temps réel
/// 
/// Expose les dernières trames reçues via un StateNotifierProvider
/// Permet au widget NMEA sniffer d'afficher les trames en live

import 'package:flutter_riverpod/flutter_riverpod.dart';

// Classe pour stocker une trame NMEA avec timestamp
class NmeaSentence {
  final String raw;
  final DateTime timestamp;
  final bool isValid;
  final String? errorMessage;

  const NmeaSentence({
    required this.raw,
    required this.timestamp,
    this.isValid = true,
    this.errorMessage,
  });

  @override
  String toString() => '$timestamp | $raw${!isValid ? ' ❌ $errorMessage' : ''}';
}

/// Notifier pour gérer la liste des trames NMEA
class NmeaSentencesNotifier extends Notifier<List<NmeaSentence>> {
  static const _maxHistoryLength = 50;

  @override
  List<NmeaSentence> build() {
    return [];
  }

  void addSentence(String raw, {bool isValid = true, String? error}) {
    final sentence = NmeaSentence(
      raw: raw,
      timestamp: DateTime.now(),
      isValid: isValid,
      errorMessage: error,
    );

    // Ajouter au début et limiter la taille
    state = [sentence, ...state].take(_maxHistoryLength).toList();
    // ignore: avoid_print
    print('📝 Trame ajoutée au notifier, total: ${state.length}');
  }

  void clear() {
    state = [];
  }
}

/// Liste des 50 dernières trames NMEA reçues
final nmeaSentencesProvider =
    NotifierProvider<NmeaSentencesNotifier, List<NmeaSentence>>(
  NmeaSentencesNotifier.new,
);

