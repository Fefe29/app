/// Providers pour la gestion de la télémétrie (source et configuration)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kornog/config/telemetry_config.dart';
import 'package:kornog/common/services/miniplexe_discovery.dart';

/// Notifier pour gérer le mode de source de télémétrie
class TelemetrySourceModeNotifier extends AsyncNotifier<TelemetrySourceMode> {
  @override
  Future<TelemetrySourceMode> build() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeStr = prefs.getString('telemetry_source_mode');
      if (modeStr != null) {
        // modeStr devrait être "fake" ou "network"
        for (final mode in TelemetrySourceMode.values) {
          if (mode.name == modeStr) {
            // ignore: avoid_print
            print('✓ Mode restauré depuis prefs: $modeStr');
            return mode;
          }
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('⚠️ Erreur restauration mode: $e');
    }
    return defaultTelemetrySourceMode;
  }

  Future<void> setMode(TelemetrySourceMode mode) async {
    state = AsyncData(mode);
    try {
      final prefs = await SharedPreferences.getInstance();
      // Sauver juste le name, pas le toString()
      await prefs.setString('telemetry_source_mode', mode.name);
      // ignore: avoid_print
      print('✓ Mode sauvegardé: ${mode.name}');
    } catch (e) {
      // ignore: avoid_print
      print('❌ Erreur sauvegarde mode: $e');
    }
  }
}

/// Provider pour le mode de source de télémétrie
final telemetrySourceModeProvider = AsyncNotifierProvider<TelemetrySourceModeNotifier, TelemetrySourceMode>(
  TelemetrySourceModeNotifier.new,
);

/// Notifier pour gérer la configuration réseau
class TelemetryNetworkConfigNotifier extends Notifier<TelemetryNetworkConfig> {
  @override
  TelemetryNetworkConfig build() {
    _loadFromPreferences();
    return defaultNetworkConfig;
  }

  void updateConfig(TelemetryNetworkConfig config) {
    state = config;
    _saveToPreferences();
  }

  void setEnabled(bool enabled) {
    // ignore: avoid_print
    print('⚙️ Activation réseau: $enabled');
    state = state.copyWith(enabled: enabled);
    _saveToPreferences();
  }

  void setHost(String host) {
    // ignore: avoid_print
    print('⚙️ IP configurée: $host');
    state = state.copyWith(host: host);
    _saveToPreferences();
  }

  void setPort(int port) {
    // ignore: avoid_print
    print('⚙️ Port configuré: $port');
    state = state.copyWith(port: port);
    _saveToPreferences();
  }

  void _loadFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('telemetry_network_enabled') ?? defaultNetworkConfig.enabled;
      final host = prefs.getString('telemetry_network_host') ?? defaultNetworkConfig.host;
      final port = prefs.getInt('telemetry_network_port') ?? defaultNetworkConfig.port;

      state = TelemetryNetworkConfig(
        enabled: enabled,
        host: host,
        port: port,
      );
    } catch (_) {}
  }

  void _saveToPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('telemetry_network_enabled', state.enabled);
      await prefs.setString('telemetry_network_host', state.host);
      await prefs.setInt('telemetry_network_port', state.port);
    } catch (_) {}
  }
}

/// Provider pour la configuration réseau
final telemetryNetworkConfigProvider = NotifierProvider<TelemetryNetworkConfigNotifier, TelemetryNetworkConfig>(
  TelemetryNetworkConfigNotifier.new,
);

/// State pour tracker le statut de connexion réseau
class NetworkConnectionState {
  const NetworkConnectionState({
    required this.isConnected,
    required this.lastValidData,
    required this.errorMessage,
  });

  final bool isConnected;
  final DateTime? lastValidData;
  final String? errorMessage;

  @override
  String toString() => 'NetworkConnectionState(connected=$isConnected, lastData=$lastValidData)';
}

/// Notifier pour tracker l'état de la connexion réseau
class NetworkConnectionNotifier extends Notifier<NetworkConnectionState> {
  @override
  NetworkConnectionState build() {
    return const NetworkConnectionState(
      isConnected: true, // Par défaut: on assume connecté (simulation ou connexion ok)
      lastValidData: null,
      errorMessage: null,
    );
  }

  /// Mettre à jour l'état de connexion (appelé par le NetworkTelemetryBus)
  void updateConnectionState({
    required bool isConnected,
    DateTime? lastValidData,
    String? errorMessage,
  }) {
    state = NetworkConnectionState(
      isConnected: isConnected,
      lastValidData: lastValidData,
      errorMessage: errorMessage,
    );
  }
}

/// Provider pour l'état de la connexion réseau
final networkConnectionProvider = NotifierProvider<NetworkConnectionNotifier, NetworkConnectionState>(
  NetworkConnectionNotifier.new,
);

/// Résultat de découverte du Miniplexe
class MiniplexeDiscoveryResult {
  const MiniplexeDiscoveryResult({
    required this.isLoading,
    required this.discovered,
    this.ipAddress,
    this.errorMessage,
  });

  final bool isLoading;
  final bool discovered;
  final String? ipAddress;
  final String? errorMessage;

  @override
  String toString() => 'MiniplexeDiscoveryResult(loading=$isLoading, found=$discovered, ip=$ipAddress)';
}

/// Provider pour découvrir automatiquement le Miniplexe
final miniplexeDiscoveryProvider = FutureProvider.autoDispose<MiniplexeDiscovery>((ref) async {
  return MiniplexeDiscoveryService.discoverMiniplexe();
});
