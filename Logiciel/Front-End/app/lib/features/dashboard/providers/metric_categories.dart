/// Configuration des catégories de métriques pour le dashboard
/// Organise les métriques en catégories lisibles pour l'utilisateur

class MetricInfo {
  final String key;
  final String label;
  final String? description;

  const MetricInfo({
    required this.key,
    required this.label,
    this.description,
  });
}

class MetricCategory {
  final String name;
  final String icon;
  final List<MetricInfo> metrics;

  const MetricCategory({
    required this.name,
    required this.icon,
    required this.metrics,
  });
}

const List<MetricCategory> metricCategories = [
  MetricCategory(
    name: '🧭 Navigation',
    icon: '🧭',
    metrics: [
      MetricInfo(
        key: 'nav.sog',
        label: 'Vitesse fond (SOG)',
        description: 'Vitesse par rapport au sol',
      ),
      MetricInfo(
        key: 'nav.cog',
        label: 'Route fond (COG)',
        description: 'Cap par rapport au sol',
      ),
      MetricInfo(
        key: 'nav.hdg',
        label: 'Cap compas (HDG)',
        description: 'Cap de la prise de vent',
      ),
      MetricInfo(
        key: 'nav.position',
        label: 'Position GPS',
        description: 'Latitude et longitude actuelles',
      ),
    ],
  ),
  MetricCategory(
    name: '💨 Vent',
    icon: '💨',
    metrics: [
      MetricInfo(
        key: 'wind.tws',
        label: 'Vitesse vent réel (TWS)',
        description: 'Force du vent vrai',
      ),
      MetricInfo(
        key: 'wind.twd',
        label: 'Direction vent réel (TWD)',
        description: 'Direction d\'où vient le vent',
      ),
      MetricInfo(
        key: 'wind.twa',
        label: 'Angle vent réel (TWA)',
        description: 'Angle du vent par rapport au cap',
      ),
      MetricInfo(
        key: 'wind.aws',
        label: 'Vitesse vent apparent (AWS)',
        description: 'Force du vent apparent',
      ),
      MetricInfo(
        key: 'wind.awa',
        label: 'Angle vent apparent (AWA)',
        description: 'Angle du vent apparent',
      ),
    ],
  ),
  MetricCategory(
    name: '🌊 Environnement',
    icon: '🌊',
    metrics: [
      MetricInfo(
        key: 'env.depth',
        label: 'Profondeur eau',
        description: 'Profondeur sous la coque',
      ),
      MetricInfo(
        key: 'env.waterTemp',
        label: 'Température eau',
        description: 'Température de l\'eau',
      ),
    ],
  ),
];

/// Obtenir le label lisible pour une clé de métrique
String getMetricLabel(String key) {
  for (final category in metricCategories) {
    for (final metric in category.metrics) {
      if (metric.key == key) {
        return metric.label;
      }
    }
  }
  return key; // Fallback au nom brut
}

/// Obtenir la description pour une clé de métrique
String? getMetricDescription(String key) {
  for (final category in metricCategories) {
    for (final metric in category.metrics) {
      if (metric.key == key) {
        return metric.description;
      }
    }
  }
  return null;
}

/// Obtenir la catégorie pour une clé de métrique
String? getMetricCategory(String key) {
  for (final category in metricCategories) {
    for (final metric in category.metrics) {
      if (metric.key == key) {
        return category.name;
      }
    }
  }
  return null;
}

/// Liste plate de toutes les clés de métriques
const allMetricKeys = <String>[
  'nav.sog',
  'nav.cog',
  'wind.twa',
  'wind.twd',
  'wind.tws',
  'wind.awa',
  'wind.aws',
  'nav.hdg',
  'env.depth',
  'env.waterTemp',
  'nav.position', // Contient lat + lon combinés, pas de métriques séparées
];

/// Métriques affichées par défaut
const defaultMetricKeys = <String>[
  'nav.sog',
  'nav.cog',
  'wind.twa',
  'wind.twd',
  'wind.tws',
  'nav.hdg',
  'env.depth',
  'env.waterTemp',
  'nav.position', // Position complète (lat + lon combinés)
];
