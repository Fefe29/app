/// Selected dashboard metrics provider.
/// See ARCHITECTURE_DOCS.md (section: selected_metrics.dart).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const selectedKeysPref = 'selected_metric_keys';

const allMetricKeys = <String>[
  'nav.sog','nav.cog','wind.twa','wind.twd','wind.tws','wind.awa','wind.aws',
  'nav.hdg','env.depth','env.waterTemp','nav.position',
];

const defaultMetricKeys = <String>[
  'nav.sog','nav.cog','wind.twa','wind.twd','wind.tws','nav.hdg','env.depth','env.waterTemp','nav.position',
];

class SelectedMetricsNotifier extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(selectedKeysPref);
    return (stored == null || stored.isEmpty) ? {...defaultMetricKeys} : {...stored};
  }

  Future<void> toggle(String key, bool selected) async {
    final current = {...(state.value ?? {})};
    selected ? current.add(key) : current.remove(key);
    state = AsyncData(current);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(selectedKeysPref, current.toList());
  }

  Future<void> setAll(Iterable<String> keys) async {
    final s = {...keys};
    state = AsyncData(s);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(selectedKeysPref, s.toList());
  }

  Future<void> reset() => setAll(defaultMetricKeys);
}

final selectedMetricsProvider =
    AsyncNotifierProvider<SelectedMetricsNotifier, Set<String>>(
  SelectedMetricsNotifier.new,
);
