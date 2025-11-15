/// File: lib/main.dart
/// Entry point. See ARCHITECTURE_DOCS.md (section: lib/main.dart) for details.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/router.dart';
import 'theme/app_theme.dart';
import 'package:window_manager/window_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:kornog/data/datasources/telemetry/json_telemetry_storage.dart';
import 'package:kornog/features/telemetry_recording/providers/telemetry_storage_providers.dart';
import 'package:kornog/features/analysis/domain/services/wind_history_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    windowManager.waitUntilReadyToShow().then((_) async {
      await windowManager.maximize();
      await windowManager.show();
      await windowManager.focus();
    });
  }
  
  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ⚠️ IMPORTANT: Initialiser la collecte d'historique du vent DÈS LE LANCEMENT
    // Cela garantit que les graphes accumulent des données même si la page d'analyse n'est pas ouverte
    ref.watch(windHistoryServiceProvider);
    
    // Aussi initialiser les providers d'historique pour qu'ils commencent à émettre immédiatement
    ref.watch(twdHistoryProvider);
    ref.watch(twaHistoryProvider);
    ref.watch(twsHistoryProvider);
    
    final router = ref.watch(appRouterProvider);
    final theme = ref.watch(appThemeProvider);
    return MaterialApp.router(
      title: 'App',
      theme: theme.light,
      darkTheme: theme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}

