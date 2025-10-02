/// File: lib/main.dart
/// Entry point. See ARCHITECTURE_DOCS.md (section: lib/main.dart) for details.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/router.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: App()));
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
