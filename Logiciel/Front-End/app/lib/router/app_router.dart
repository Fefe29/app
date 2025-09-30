import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/home_shell.dart';
import '../features/settings/settings_page.dart';
import '../features/dashboard/dashboard_page.dart';
import '../screens/analysis/analysis_page.dart'; // 👈 import de ta page Analysis

/// Fournit la configuration de navigation à l’application.
/// On utilise un ShellRoute pour afficher la barre de navigation globale.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            HomeShell(child: child, location: state.uri.toString()),
        routes: [
          GoRoute(
            path: '/',
            name: 'dashboard',
            builder: (_, __) => const DashboardPage(),
          ),
          GoRoute(
            path: '/charts',
            name: 'charts',
            builder: (_, __) => const _PlaceholderPage(label: 'Charts'),
          ),
          GoRoute(
            path: '/alarms',
            name: 'alarms',
            builder: (_, __) => const _PlaceholderPage(label: 'Alarms'),
          ),
          GoRoute(
            path: '/analysis', // 👈 route vers ta page
            name: 'analysis',
            builder: (_, __) => const AnalysisPage(),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (_, __) => const SettingsPage(),
          ),
        ],
      ),
    ],
  );
});

/// Page temporaire en attendant les vraies implémentations
class _PlaceholderPage extends StatelessWidget {
  final String label;
  const _PlaceholderPage({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        style: const TextStyle(fontSize: 22),
      ),
    );
  }
}
