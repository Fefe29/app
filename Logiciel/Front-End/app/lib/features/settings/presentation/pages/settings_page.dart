/// Settings page (units/theme/etc.).
/// See ARCHITECTURE_DOCS.md (section: settings_page.dart).
// ------------------------------
// File: lib/features/settings/settings_page.dart
// ------------------------------
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kornog/common/providers/telemetry_providers.dart';
import 'package:kornog/common/services/miniplexe_discovery.dart';
import 'package:kornog/config/telemetry_config.dart';
import 'package:kornog/features/settings/presentation/widgets/nmea_sniffer_widget.dart';
import 'package:kornog/theme/theme_provider.dart';


class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
          tooltip: 'Retour',
        ),
        elevation: 1,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.settings), text: 'Général'),
            Tab(icon: Icon(Icons.wifi), text: 'Réseau'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Onglet 1: Général
          _buildGeneralTab(),
          // Onglet 2: Réseau
          _buildNetworkTab(),
        ],
      ),
    );
  }

  Widget _buildGeneralTab() {
    final themeMode = ref.watch(themeModeProvider);
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Apparence', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        ListTile(
          title: const Text('Mode thème'),
          subtitle: Text(
            themeMode == ThemeMode.system 
              ? 'Système (suit les paramètres du téléphone)'
              : themeMode == ThemeMode.dark
                ? 'Thème sombre (forcé)'
                : 'Thème clair (forcé)',
          ),
          trailing: DropdownButton<ThemeMode>(
            value: themeMode,
            onChanged: (ThemeMode? newMode) {
              if (newMode != null) {
                ref.read(themeModeProvider.notifier).setThemeMode(newMode);
              }
            },
            items: const [
              DropdownMenuItem(
                value: ThemeMode.system,
                child: Text('Système'),
              ),
              DropdownMenuItem(
                value: ThemeMode.light,
                child: Text('Clair'),
              ),
              DropdownMenuItem(
                value: ThemeMode.dark,
                child: Text('Sombre'),
              ),
            ],
          ),
        ),
        const Divider(),
        const SizedBox(height: 16),
        const Text('App', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('À propos'),
          subtitle: const Text('Version 0.1.0'),
        ),
      ],
    );
  }

  Widget _buildNetworkTab() {
    return const Padding(
      padding: EdgeInsets.all(8.0),
      child: _NetworkConfigTabContent(),
    );
  }
}

/// Widget pour la configuration réseau dans l'onglet
class _NetworkConfigTabContent extends ConsumerStatefulWidget {
  const _NetworkConfigTabContent();

  @override
  ConsumerState<_NetworkConfigTabContent> createState() =>
      _NetworkConfigTabContentState();
}

class _NetworkConfigTabContentState
    extends ConsumerState<_NetworkConfigTabContent>
    with SingleTickerProviderStateMixin {
  late TextEditingController _hostController;
  late TextEditingController _portController;
  late TabController _internalTabController;

  @override
  void initState() {
    super.initState();
    _internalTabController = TabController(length: 2, vsync: this);
    final config = ref.read(telemetryNetworkConfigProvider);
    _hostController = TextEditingController(text: config.host);
    _portController = TextEditingController(text: config.port.toString());
  }

  @override
  void dispose() {
    _internalTabController.dispose();
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sourceModeAsync = ref.watch(telemetrySourceModeProvider);
    final networkConfig = ref.watch(telemetryNetworkConfigProvider);
    final connectionState = ref.watch(networkConnectionProvider);
    final discoveryAsync = ref.watch(miniplexeDiscoveryProvider);

    return sourceModeAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('Erreur: $error'),
      ),
      data: (sourceMode) => DefaultTabController(
        length: 2,
        child: Column(
          children: [
            TabBar(
              controller: _internalTabController,
              tabs: const [
                Tab(text: 'Configuration'),
                Tab(text: 'Trames NMEA'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _internalTabController,
                children: [
                  // Configuration
                  _buildConfigView(sourceMode, networkConfig, connectionState, discoveryAsync),
                  // Trames NMEA
                  const NmeaSnifferWidget(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigView(
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
          // Mode source
          const Text('Mode Source', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    await ref.read(telemetrySourceModeProvider.notifier).setMode(TelemetrySourceMode.fake);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: sourceMode == TelemetrySourceMode.fake
                        ? Colors.blue
                        : Colors.grey[300],
                  ),
                  child: Text(
                    'Simulation',
                    style: TextStyle(
                      color: sourceMode == TelemetrySourceMode.fake
                          ? Colors.white
                          : Colors.black,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    await ref.read(telemetrySourceModeProvider.notifier).setMode(TelemetrySourceMode.network);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: sourceMode == TelemetrySourceMode.network
                        ? Colors.blue
                        : Colors.grey[300],
                  ),
                  child: Text(
                    'Réseau',
                    style: TextStyle(
                      color: sourceMode == TelemetrySourceMode.network
                          ? Colors.white
                          : Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Découverte automatique
          if (sourceMode == TelemetrySourceMode.network)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Découverte Automatique',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                discoveryAsync.when(
                  data: (discovery) {
                    if (discovery.found && discovery.ipAddress != null) {
                      return Container(
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
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('IP: ${discovery.ipAddress}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('Port: ${discovery.port}', style: TextStyle(color: Colors.grey[600])),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  ref.read(telemetryNetworkConfigProvider.notifier).setHost(discovery.ipAddress!);
                                  ref.read(telemetryNetworkConfigProvider.notifier).setPort(discovery.port);
                                  // Activer la connexion réseau
                                  ref.read(telemetryNetworkConfigProvider.notifier).setEnabled(true);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Paramètres mis à jour et activés')),
                                  );
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                child: const Text('Utiliser ces paramètres', style: TextStyle(color: Colors.white)),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(8)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info, color: Colors.orange[700]),
                              const SizedBox(width: 8),
                              Text('Miniplexe non trouvé', style: TextStyle(color: Colors.orange[700])),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(),
                  ),
                  error: (err, _) => Text('Erreur: $err'),
                ),
                const SizedBox(height: 24),
              ],
            ),

          // Activation / Désactivation
          if (sourceMode == TelemetrySourceMode.network)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Connexion Réseau',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                Switch(
                  value: networkConfig.enabled,
                  onChanged: (value) {
                    ref.read(telemetryNetworkConfigProvider.notifier).setEnabled(value);
                  },
                ),
              ],
            ),
          const SizedBox(height: 24),

          // Configuration manuelle
          if (sourceMode == TelemetrySourceMode.network)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Configuration Manuelle',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  controller: _hostController,
                  decoration: InputDecoration(
                    labelText: 'IP du Miniplexe',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final port = int.tryParse(value);
                    if (port != null) {
                      ref.read(telemetryNetworkConfigProvider.notifier).setPort(port);
                    }
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),

          // État connexion
          const Text('État Connexion',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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
                  color: connectionState.isConnected ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}