/// AppShell: scaffolds global navigation & surrounding chrome.
/// See ARCHITECTURE_DOCS.md (section: lib/app/app_shell.dart).
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Import corrigé : utiliser l'import package (l'ancien chemin cherchait lib/app/features/... inexistant)
import 'package:kornog/features/analysis/presentation/widgets/analysis_filter_drawer.dart';

class HomeShell extends ConsumerStatefulWidget {
  final Widget child;
  final String location;
  const HomeShell({super.key, required this.child, required this.location});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  bool get _isAnalysis => widget.location.startsWith('/analysis');

  int _indexFromLocation(String location) {
    if (location.startsWith('/charts')) return 1;
    if (location.startsWith('/alarms')) return 2;
    if (location.startsWith('/analysis')) return 3;
    return 0;
  }

  void _go(int idx) {
    switch (idx) {
      case 0: context.go('/'); break;
      case 1: context.go('/charts'); break;
      case 2: context.go('/alarms'); break;
      case 3: context.go('/analysis'); break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final idx = _indexFromLocation(widget.location);

    return Scaffold(
      // 👉 Drawer uniquement sur la page Analysis
      drawer: _isAnalysis ? const AnalysisFilterDrawer() : null,

      // AppBar supprimé pour maximiser l'espace d'affichage

      body: Stack(
        children: [
          SafeArea(child: widget.child),
          // Floating settings button (smaller, white background, black icon)
          Positioned(
            top: 16,
            right: 16,
            child: Material(
              color: Colors.transparent,
              elevation: 4,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => context.go('/settings'),
                child: Ink(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  width: 36,
                  height: 36,
                  child: const Icon(Icons.settings, color: Colors.black, size: 20),
                ),
              ),
            ),
          ),
        ],
      ),

      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: _go,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Tableau',
          ),
          const NavigationDestination(
            icon: Icon(Icons.show_chart_outlined),
            selectedIcon: Icon(Icons.show_chart),
            label: 'Carte',
          ),
          const NavigationDestination(
            icon: Icon(Icons.alarm_outlined),
            selectedIcon: Icon(Icons.alarm),
            label: 'Alarmes',
          ),
          const NavigationDestination(
            icon: Icon(Icons.calculate_outlined),
            selectedIcon: Icon(Icons.calculate),
            label: 'Analyse',
          ),
        ],
        labelTextStyle: MaterialStatePropertyAll(
          TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
