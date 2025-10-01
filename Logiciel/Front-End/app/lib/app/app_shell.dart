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

      appBar: AppBar(
        // Bouton en haut à gauche qui ouvre le drawer (uniquement en Analysis)
        leading: _isAnalysis
            ? Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.tune),
                  tooltip: 'Select plots',
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              )
            : null,
        title: const Text(''),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),

      body: SafeArea(child: widget.child),

      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: _go,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dash',
          ),
          NavigationDestination(
            icon: Icon(Icons.show_chart_outlined),
            selectedIcon: Icon(Icons.show_chart),
            label: 'Charts',
          ),
          NavigationDestination(
            icon: Icon(Icons.alarm_outlined),
            selectedIcon: Icon(Icons.alarm),
            label: 'Alarms',
          ),
          NavigationDestination(
            icon: Icon(Icons.calculate_outlined),
            selectedIcon: Icon(Icons.calculate),
            label: 'Analysis',
          ),
        ],
      ),
    );
  }
}
