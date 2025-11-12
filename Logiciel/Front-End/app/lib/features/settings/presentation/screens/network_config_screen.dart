/// Écran de configuration de la connexion réseau NMEA
/// 
/// Permet à l'utilisateur de:
/// - Découvrir automatiquement le Miniplexe
/// - Basculer entre simulation et réseau réel
/// - Configurer l'IP et le port du Miniplexe
/// - Tester la connexion
/// - Voir l'état de la connexion
/// - Visualiser les trames NMEA en direct

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kornog/config/telemetry_config.dart';
import 'package:kornog/common/providers/telemetry_providers.dart';
import 'package:kornog/common/services/miniplexe_discovery.dart';
import 'package:kornog/features/settings/presentation/widgets/nmea_sniffer_widget.dart';

class NetworkConfigScreen extends ConsumerStatefulWidget {
  const NetworkConfigScreen({super.key});

  @override
  ConsumerState<NetworkConfigScreen> createState() => _NetworkConfigScreenState();
}

class _NetworkConfigScreenState extends ConsumerState<NetworkConfigScreen>
    with SingleTickerProviderStateMixin {
  late TextEditingController _hostController;
  late TextEditingController _portController;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final config = ref.read(telemetryNetworkConfigProvider);
    _hostController = TextEditingController(text: config.host);
    _portController = TextEditingController(text: config.port.toString());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sourceMode = ref.watch(telemetrySourceModeProvider);
    final networkConfig = ref.watch(telemetryNetworkConfigProvider);
    final connectionState = ref.watch(networkConnectionProvider);
    final discoveryAsync = ref.watch(miniplexeDiscoveryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuration Télémétrie'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.settings), text: 'Configuration'),
            Tab(icon: Icon(Icons.radio), text: 'Trames NMEA'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Onglet 1: Configuration
          _buildConfigTab(sourceMode, networkConfig, connectionState, discoveryAsync),
          // Onglet 2: Trames NMEA
          _buildNmeaTab(),
        ],
      ),
    );
  }

  Widget _buildConfigTab(
    TelemetrySourceMode sourceMode,
    TelemetryNetworkConfig networkConfig,
    NetworkConnectionState connectionState,
    AsyncValue<MiniplexeDiscovery> discoveryAsync,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section: Mode source
          _buildSourceModeSection(sourceMode),
          const SizedBox(height: 24),

          // Section: Découverte automatique
          if (sourceMode == TelemetrySourceMode.network)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAutoDiscoverySection(discoveryAsync, ref, networkConfig),
                const SizedBox(height: 24),
              ],
            ),

          // Section: Configuration réseau
          if (sourceMode == TelemetrySourceMode.network)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildNetworkConfigSection(networkConfig),
                const SizedBox(height: 24),
              ],
            ),

          // Section: État de connexion
          _buildConnectionStatusSection(connectionState, networkConfig),
          const SizedBox(height: 24),

          // Section: Boutons d'action
          _buildActionButtonsSection(sourceMode, networkConfig),
        ],
      ),
    );
  }

  Widget _buildNmeaTab() {
    return const Padding(
      padding: EdgeInsets.all(8.0),
      child: NmeaSnifferWidget(),
    );
  }

  Widget _buildAutoDiscoverySection(
    AsyncValue<MiniplexeDiscovery> discoveryAsync,
    WidgetRef ref,
    TelemetryNetworkConfig config,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Découverte Automatique',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            discoveryAsync.when(
              data: (discovery) {
                if (discovery.found && discovery.ipAddress != null) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green, width: 2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Miniplexe trouvé! ✅',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'IP: ${discovery.ipAddress}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Port: ${discovery.port}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  ref
                                      .read(telemetryNetworkConfigProvider.notifier)
                                      .setHost(discovery.ipAddress!);
                                  ref
                                      .read(telemetryNetworkConfigProvider.notifier)
                                      .setPort(discovery.port);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Configuration mise à jour avec les valeurs détectées'),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                                child: const Text(
                                  'Utiliser ces paramètres',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                } else {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info, color: Colors.orange[700], size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Miniplexe non trouvé',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          discovery.errorMessage ?? 'Vérifiez que le Miniplexe est allumé et connecté au WiFi',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }
              },
              loading: () => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('Recherche du Miniplexe...'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Assurez-vous d\'être connecté au WiFi du bateau',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              error: (err, st) => Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Erreur: $err',
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceModeSection(TelemetrySourceMode sourceMode) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mode Source',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: sourceMode == TelemetrySourceMode.fake
                        ? null
                        : () {
                            ref.read(telemetrySourceModeProvider.notifier).setMode(TelemetrySourceMode.fake);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: sourceMode == TelemetrySourceMode.fake
                          ? Colors.blue
                          : Colors.grey[300],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Text(
                        '🎮 Simulation',
                        style: TextStyle(
                          color: sourceMode == TelemetrySourceMode.fake
                              ? Colors.white
                              : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: sourceMode == TelemetrySourceMode.network
                        ? null
                        : () {
                            ref.read(telemetrySourceModeProvider.notifier).setMode(TelemetrySourceMode.network);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: sourceMode == TelemetrySourceMode.network
                          ? Colors.green
                          : Colors.grey[300],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Text(
                        '🌐 Réseau',
                        style: TextStyle(
                          color: sourceMode == TelemetrySourceMode.network
                              ? Colors.white
                              : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              sourceMode == TelemetrySourceMode.fake
                  ? 'Mode simulation: données générées localement'
                  : 'Mode réseau: connexion UDP au Miniplexe 2Wi',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkConfigSection(TelemetryNetworkConfig config) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paramètres Réseau',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _hostController,
              decoration: InputDecoration(
                labelText: 'Adresse IP du Miniplexe',
                hintText: '192.168.1.100',
                prefixIcon: const Icon(Icons.router),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) {
                ref.read(telemetryNetworkConfigProvider.notifier).setHost(value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _portController,
              decoration: InputDecoration(
                labelText: 'Port UDP',
                hintText: '10110',
                prefixIcon: const Icon(Icons.exit_to_app),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                final port = int.tryParse(value);
                if (port != null) {
                  ref.read(telemetryNetworkConfigProvider.notifier).setPort(port);
                }
              },
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💡 Conseil',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Pour trouver l\'IP du Miniplexe, vérifiez votre routeur WiFi du bateau.\n'
                    'Port standard: 10110 ou 5013 (dépend de la config du Miniplexe)',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatusSection(
    NetworkConnectionState connectionState,
    TelemetryNetworkConfig config,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'État de Connexion',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: connectionState.isConnected ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  connectionState.isConnected ? 'Connecté ✅' : 'Déconnecté ❌',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: connectionState.isConnected ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            if (connectionState.lastValidData != null) ...[
              const SizedBox(height: 8),
              Text(
                'Dernières données: ${connectionState.lastValidData}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
            if (connectionState.errorMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Erreur: ${connectionState.errorMessage}',
                  style: const TextStyle(fontSize: 12, color: Colors.red),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Cible: ${config.host}:${config.port}',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtonsSection(
    TelemetrySourceMode sourceMode,
    TelemetryNetworkConfig config,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Actions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (sourceMode == TelemetrySourceMode.network)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: config.enabled
                      ? () async {
                          ref.read(telemetryNetworkConfigProvider.notifier).setEnabled(false);
                          await Future.delayed(const Duration(milliseconds: 500));
                          if (mounted) {
                            ref.read(telemetryNetworkConfigProvider.notifier).setEnabled(true);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Reconnexion lancée...')),
                            );
                          }
                        }
                      : null,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tester la connexion'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Fermer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
