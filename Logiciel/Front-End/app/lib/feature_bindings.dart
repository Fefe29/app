// ------------------------------
// File: lib/feature_bindings.dart (wire pages to routes)
// ------------------------------
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'features/dashboard/dashboard_page.dart';
import 'features/charts/charts_page.dart';
import 'features/alarms/alarms_page.dart';


final routesProvider = Provider<List<GoRoute>>((ref) => [
GoRoute(path: '/', builder: (_, __) => const DashboardPage()),
GoRoute(path: '/charts', builder: (_, __) => const ChartsPage()),
GoRoute(path: '/alarms', builder: (_, __) => const AlarmsPage()),
]);