import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeShell extends StatefulWidget {
  final Widget child;
  final String location; // <-- ajouter
  const HomeShell({super.key, required this.child, required this.location});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _indexFromLocation(String location) {
    if (location.startsWith('/charts')) return 1;
    if (location.startsWith('/alarms')) return 2;
    if (location.startsWith('/settings')) return 3;
    return 0;
  }

  void _go(int idx) {
    switch (idx) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/charts');
        break;
      case 2:
        context.go('/alarms');
        break;
      case 3:
        context.go('/settings');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final idx = _indexFromLocation(widget.location); // <-- utiliser la prop

    return Scaffold(
      appBar: AppBar(title: const Text('Kornog')),
      body: SafeArea(child: widget.child),
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: _go,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Dash'),
          NavigationDestination(
              icon: Icon(Icons.show_chart_outlined),
              selectedIcon: Icon(Icons.show_chart),
              label: 'Charts'),
          NavigationDestination(
              icon: Icon(Icons.alarm_outlined),
              selectedIcon: Icon(Icons.alarm),
              label: 'Alarms'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings'),
        ],
      ),
    );
  }
}
