/// Service de collecte d'historique des données télémétriques
/// Collecte les données TWD, TWA, TWS pour analyse et visualisation
import 'dart:async';
import 'dart:collection';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kornog/common/providers/app_providers.dart';
import 'package:kornog/domain/entities/telemetry.dart';

/// Point de données historique avec timestamp
class HistoryDataPoint {
  const HistoryDataPoint({
    required this.timestamp,
    required this.value,
  });

  final DateTime timestamp;
  final double value;

  @override
  String toString() => 'HistoryDataPoint($timestamp: $value)';
}

/// Service de collecte d'historique des métriques de vent
class WindHistoryService {
  WindHistoryService({
    this.maxPoints = 300, // 5 minutes à 1 point/seconde
    this.maxAgeMinutes = 10,
  });

  final int maxPoints;
  final int maxAgeMinutes;

  final Queue<HistoryDataPoint> _twdHistory = Queue();
  final Queue<HistoryDataPoint> _twaHistory = Queue();
  final Queue<HistoryDataPoint> _twsHistory = Queue();

  StreamSubscription<TelemetrySnapshot>? _subscription;

  /// Démarrer la collecte d'historique
  void startCollection(Stream<TelemetrySnapshot> telemetryStream) {
    _subscription?.cancel();
    _subscription = telemetryStream.listen(_onTelemetrySnapshot);
  }

  /// Arrêter la collecte
  void stopCollection() {
    _subscription?.cancel();
    _subscription = null;
  }

  void _onTelemetrySnapshot(TelemetrySnapshot snapshot) {
    final now = DateTime.now();
    
    // Collecter TWD (True Wind Direction)
    final twd = snapshot.metrics['wind.twd']?.value;
    if (twd != null) {
      _addPoint(_twdHistory, HistoryDataPoint(timestamp: now, value: twd));
    }

    // Collecter TWA (True Wind Angle) 
    final twa = snapshot.metrics['wind.twa']?.value;
    if (twa != null) {
      _addPoint(_twaHistory, HistoryDataPoint(timestamp: now, value: twa));
    }

    // Collecter TWS (True Wind Speed)
    final tws = snapshot.metrics['wind.tws']?.value;
    if (tws != null) {
      _addPoint(_twsHistory, HistoryDataPoint(timestamp: now, value: tws));
    }
  }

  void _addPoint(Queue<HistoryDataPoint> history, HistoryDataPoint point) {
    history.add(point);
    
    // Limiter le nombre de points
    while (history.length > maxPoints) {
      history.removeFirst();
    }

    // Supprimer les points trop anciens
    final cutoff = DateTime.now().subtract(Duration(minutes: maxAgeMinutes));
    while (history.isNotEmpty && history.first.timestamp.isBefore(cutoff)) {
      history.removeFirst();
    }
  }

  /// Obtenir l'historique TWD
  List<HistoryDataPoint> get twdHistory => List.unmodifiable(_twdHistory);
  
  /// Obtenir l'historique TWA  
  List<HistoryDataPoint> get twaHistory => List.unmodifiable(_twaHistory);
  
  /// Obtenir l'historique TWS
  List<HistoryDataPoint> get twsHistory => List.unmodifiable(_twsHistory);

  /// Vider l'historique
  void clearHistory() {
    _twdHistory.clear();
    _twaHistory.clear();
    _twsHistory.clear();
  }

  void dispose() {
    stopCollection();
  }
}

/// Provider du service d'historique
final windHistoryServiceProvider = Provider<WindHistoryService>((ref) {
  final service = WindHistoryService();
  
  // Écouter les snapshots de télémétrie
  ref.listen<AsyncValue<TelemetrySnapshot>>(snapshotStreamProvider, (previous, next) {
    next.whenData((snapshot) {
      service._onTelemetrySnapshot(snapshot);
    });
  });
  
  // Nettoyer quand le provider est supprimé
  ref.onDispose(() {
    service.dispose();
  });
  
  return service;
});

/// Provider de l'historique TWD
final twdHistoryProvider = StreamProvider<List<HistoryDataPoint>>((ref) {
  final service = ref.watch(windHistoryServiceProvider);
  
  return Stream.periodic(const Duration(seconds: 1), (_) => service.twdHistory);
});

/// Provider de l'historique TWA
final twaHistoryProvider = StreamProvider<List<HistoryDataPoint>>((ref) {
  final service = ref.watch(windHistoryServiceProvider);
  
  return Stream.periodic(const Duration(seconds: 1), (_) => service.twaHistory);
});

/// Provider de l'historique TWS  
final twsHistoryProvider = StreamProvider<List<HistoryDataPoint>>((ref) {
  final service = ref.watch(windHistoryServiceProvider);
  
  return Stream.periodic(const Duration(seconds: 1), (_) => service.twsHistory);
});