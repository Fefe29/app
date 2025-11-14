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
