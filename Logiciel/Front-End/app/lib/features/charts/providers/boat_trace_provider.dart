/// Provider pour la trace du bateau (historique des positions)
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kornog/features/charts/domain/models/geographic_position.dart';
import 'package:kornog/features/telemetry_recording/providers/telemetry_storage_providers.dart';
import 'boat_position_provider.dart';

class BoatTraceNotifier extends Notifier<List<GeographicPosition>> {
  static const maxTracePoints = 500; // Limiter la trace à 500 points pour éviter les perfs

  @override
  List<GeographicPosition> build() {
    // Écouter les changements de position du bateau
    ref.listen<AsyncValue<BoatPosition?>>(boatPositionProvider, (prev, next) {
      // Vérifier si on doit enregistrer la trace
      final recordingOptions = ref.watch(currentRecordingOptionsProvider);
      final shouldRecordTrace = recordingOptions?.recordTrace ?? false;
      
      // N'ajouter à la trace que si on est en enregistrement ET que la trace est sélectionnée
      if (!shouldRecordTrace) {
        // Réinitialiser la trace si elle n'est pas sélectionnée
        if (state.isNotEmpty) {
          state = [];
        }
        return;
      }
      
      next.whenData((position) {
        if (position != null) {
          // Ajouter la position à la trace
          state = [
            ...state,
            GeographicPosition(
              latitude: position.latitude,
              longitude: position.longitude,
            ),
          ];
          
          // Limiter la trace si elle devient trop longue
          if (state.length > maxTracePoints) {
            state = state.sublist(state.length - maxTracePoints);
          }
        }
      });
    });

    return [];
  }
}

final boatTraceProvider = NotifierProvider<BoatTraceNotifier, List<GeographicPosition>>(
  () => BoatTraceNotifier(),
);
