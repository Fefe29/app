/// Configuration pour les sources de télémétrie
/// 
/// Permet de basculer entre:
/// - Simulation locale (FakeTelemetryBus)
/// - Connexion réseau UDP (NetworkTelemetryBus) au Miniplexe 2Wi

enum TelemetrySourceMode {
  /// Simulation locale (mode développement/test)
  fake,
  /// Connexion UDP au Miniplexe 2Wi réel
  network,
}

/// Configuration persistée pour la connexion réseau
class TelemetryNetworkConfig {
  const TelemetryNetworkConfig({
    this.enabled = false,
    this.host = '192.168.1.100',
    this.port = 10110,
  });

  final bool enabled;
  final String host;
  final int port;

  TelemetryNetworkConfig copyWith({
    bool? enabled,
    String? host,
    int? port,
  }) {
    return TelemetryNetworkConfig(
      enabled: enabled ?? this.enabled,
      host: host ?? this.host,
      port: port ?? this.port,
    );
  }

  @override
  String toString() => 'TelemetryNetworkConfig(enabled=$enabled, $host:$port)';
}

/// Mode de fonctionnement par défaut
const defaultTelemetrySourceMode = TelemetrySourceMode.fake;

/// Configuration réseau par défaut
const defaultNetworkConfig = TelemetryNetworkConfig(
  enabled: false,
  host: '192.168.1.100',
  port: 10110,
);
