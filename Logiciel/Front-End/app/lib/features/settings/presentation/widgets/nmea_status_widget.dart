/// Widget pour afficher le statut de connexion NMEA dans l'interface
/// 
/// Peut être intégré dans la barre d'app ou une zone de status

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kornog/config/telemetry_config.dart';
import 'package:kornog/common/providers/telemetry_providers.dart';
import 'package:kornog/features/settings/presentation/screens/network_config_screen.dart';

/// Widget de statut de connexion NMEA (petit, à afficher en haut)
class NmeaStatusWidget extends ConsumerWidget {
  const NmeaStatusWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourceMode = ref.watch(telemetrySourceModeProvider);
    final networkConfig = ref.watch(telemetryNetworkConfigProvider);
    final connectionState = ref.watch(networkConnectionProvider);

    if (sourceMode == TelemetrySourceMode.fake) {
      // Mode simulation: afficher badge bleu
      return Tooltip(
        message: 'Mode simulation (données générées)',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue[100],
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videogame_asset, size: 14, color: Colors.blue),
              SizedBox(width: 4),
              Text(
                'Simulation',
                style: TextStyle(fontSize: 12, color: Colors.blue),
              ),
            ],
          ),
        ),
      );
    } else {
      // Mode réseau: afficher badge vert (connecté) ou rouge (déconnecté)
      return GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const NetworkConfigScreen(),
            ),
          );
        },
        child: Tooltip(
          message: connectionState.isConnected
              ? 'NMEA réseau connecté à ${networkConfig.host}:${networkConfig.port}'
              : 'NMEA réseau déconnecté - Cliquer pour configurer',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: connectionState.isConnected ? Colors.green[100] : Colors.red[100],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  connectionState.isConnected ? Icons.cloud_done : Icons.cloud_off,
                  size: 14,
                  color: connectionState.isConnected ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  connectionState.isConnected ? 'NMEA OK' : 'NMEA ❌',
                  style: TextStyle(
                    fontSize: 12,
                    color: connectionState.isConnected ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }
}

/// Écran des paramètres avec accès à la configuration réseau
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourceMode = ref.watch(telemetrySourceModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.router),
            title: const Text('Connexion Télémétrie'),
            subtitle: Text(
              sourceMode == TelemetrySourceMode.fake
                  ? 'Mode: Simulation'
                  : 'Mode: Réseau NMEA',
            ),
            trailing: const Icon(Icons.arrow_forward),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const NetworkConfigScreen(),
                ),
              );
            },
          ),
          const Divider(),
          // Autres paramètres à ajouter ici
        ],
      ),
    );
  }
}
