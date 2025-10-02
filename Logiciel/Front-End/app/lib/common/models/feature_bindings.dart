/// Feature binding models & toggles.
/// See ARCHITECTURE_DOCS.md (section: lib/common/models/feature_bindings.dart).
// ------------------------------
// File: lib/feature_bindings.dart (wire pages to routes)
// ------------------------------
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/charts/presentation/pages/chart_page.dart';
import '../../features/alarms/presentation/pages/alarms_page.dart';


final routesProvider = Provider<List<GoRoute>>((ref) => [
GoRoute(path: '/', builder: (_, __) => const DashboardPage()),
GoRoute(path: '/charts', builder: (_, __) => const ChartsPage()),
GoRoute(path: '/alarms', builder: (_, __) => const AlarmsPage()),
]);