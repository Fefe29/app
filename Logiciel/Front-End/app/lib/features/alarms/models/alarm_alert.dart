/// Représente une alerte visuelle à afficher pour une alarme déclenchée
class AlarmAlert {
  final String type; // 'depth', 'windShift', 'windDrop', 'windRaise', 'anchor'
  final String title; // Titre de l'alerte
  final String description; // Description de l'alarme
  final DateTime triggeredAt; // Moment du déclenchement

  const AlarmAlert({
    required this.type,
    required this.title,
    required this.description,
    required this.triggeredAt,
  });

  @override
  String toString() => 'AlarmAlert($type: $title)';
}
