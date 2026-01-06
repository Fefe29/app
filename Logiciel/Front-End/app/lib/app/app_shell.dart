/// AppShell: scaffolds global navigation & surrounding chrome.
/// See ARCHITECTURE_DOCS.md (section: lib/app/app_shell.dart).
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
// Import corrigé : utiliser l'import package (l'ancien chemin cherchait lib/app/features/... inexistant)
import 'package:kornog/features/analysis/presentation/widgets/analysis_filter_drawer.dart';

/// Notifier pour gérer la visibilité des barres
class BarsVisibilityNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void show() => state = true;
  void hide() => state = false;
}

/// Provider pour tracker la visibilité des barres (AppBar + BottomNavBar)
final barsVisibilityProvider = NotifierProvider<BarsVisibilityNotifier, bool>(
  BarsVisibilityNotifier.new,
);

class HomeShell extends ConsumerStatefulWidget {
  final Widget child;
  final String location;
  const HomeShell({super.key, required this.child, required this.location});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  Timer? _hideTimer;
  static const _hideDuration = Duration(seconds: 5);

  bool get _isAnalysis => widget.location.startsWith('/analysis');
  bool get _isSettings => widget.location.startsWith('/settings');

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

  /// Affiche les barres et relance le timer de disparition
  void _showBarsAndResetTimer() {
    ref.read(barsVisibilityProvider.notifier).show();
    _hideTimer?.cancel();
    _hideTimer = Timer(_hideDuration, () {
      if (mounted) {
        ref.read(barsVisibilityProvider.notifier).hide();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    // Lance le timer au démarrage
    _hideTimer = Timer(_hideDuration, () {
      if (mounted) {
        ref.read(barsVisibilityProvider.notifier).hide();
      }
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final idx = _indexFromLocation(widget.location);
    // Responsive label size for bottom navigation
    final screenWidth = MediaQuery.of(context).size.width;
    // Choose a font size proportional to width, clamp between 12 and 18
    final navLabelSize = (screenWidth * 0.04).clamp(12.0, 18.0);

    // Watch la visibilité des barres
    final barsVisible = ref.watch(barsVisibilityProvider);

    return Scaffold(
      // 👉 Drawer uniquement sur la page Analysis
      drawer: _isAnalysis ? const AnalysisFilterDrawer() : null,

      // AppBar supprimé pour maximiser l'espace d'affichage

      body: MouseRegion(
        onEnter: (_) => _showBarsAndResetTimer(),
        onHover: (_) => _showBarsAndResetTimer(),
        child: GestureDetector(
          onTap: _showBarsAndResetTimer,
          child: Stack(
            children: [
              SafeArea(child: widget.child),
              // Floating settings button (smaller, white background, black icon)
              // Masqué si on est déjà sur la page settings ou si barres cachées
              if (barsVisible && !_isSettings)
                Positioned(
                  top: 16,
                  right: 16,
                  child: Builder(builder: (context) {
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    final bg = isDark ? Theme.of(context).colorScheme.surface : Colors.white;
                    final iconColor = isDark ? Colors.white : Colors.black;

                    return Material(
                      color: Colors.transparent,
                      elevation: 4,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => context.go('/settings'),
                        child: Ink(
                          decoration: BoxDecoration(
                            color: bg,
                            shape: BoxShape.circle,
                          ),
                          width: 36,
                          height: 36,
                          child: Icon(Icons.settings, color: iconColor, size: 20),
                        ),
                      ),
                    );
                  }),
                ),
            ],
          ),
        ),
      ),

      bottomNavigationBar: barsVisible
          ? NavigationBar(
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
              // Use responsive label size computed above
              labelTextStyle: MaterialStatePropertyAll(
                TextStyle(fontSize: navLabelSize, fontWeight: FontWeight.w600),
              ),
            )
          : null,
    );
  }
}
