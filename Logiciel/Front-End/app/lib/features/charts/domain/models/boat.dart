/// Transposition de la classe `Bateau` (Bateau.py) en Dart.
/// Fournit un conteneur simple pour les caractéristiques physiques
/// et la table de polaires associée.
/// \n
import 'polar_table.dart';
import 'geographic_position.dart';

class Boat {
  Boat({
    required this.lengthMeters,
    required this.beamMeters,
    required this.draftMeters,
    required this.position,
    required this.polars,
  });

  double lengthMeters; // Longueur
  double beamMeters; // Largeur
  double draftMeters; // Tirant d'eau

  GeographicPosition position; // Position géographique courante
  
  final PolarTable? polars; // Peut être null si non chargé

  final List<GeographicPosition> _positionHistory = [];

  /// Legacy getters for compatibility with existing code
  double get x => tempLocalPos?.x ?? 0.0;
  double get y => tempLocalPos?.y ?? 0.0;
  
  /// Temporary local position for backward compatibility
  LocalPosition? tempLocalPos;

  /// Legacy constructor (will be removed after migration)
  Boat.legacy({
    required this.lengthMeters,
    required this.beamMeters,
    required this.draftMeters,
    required double x,
    required double y,
    required this.polars,
  }) : position = const GeographicPosition(latitude: 0, longitude: 0),
       tempLocalPos = LocalPosition(x: x, y: y);

  /// Enregistre la position actuelle dans l'historique.
  void snapshotPosition() {
    _positionHistory.add(position);
  }

  /// Met à jour la position et garde une trace historique (optionnel).
  void moveTo(GeographicPosition newPosition, {bool record = true}) {
    position = newPosition;
    if (record) snapshotPosition();
  }

  /// Legacy moveTo with x/y coordinates
  void moveToXY(double newX, double newY, {bool record = true}) {
    tempLocalPos = LocalPosition(x: newX, y: newY);
    if (record) {
      // For legacy compatibility, we'll create a fake geographic position
      _positionHistory.add(position);
    }
  }

  /// Retourne la position géographique courante.
  GeographicPosition get currentPosition => position;

  /// Legacy position getter
  List<double> get legacyPosition => [x, y];

  /// Historique des positions (copie non modifiable).
  List<GeographicPosition> get positionHistory => List.unmodifiable(_positionHistory);

  /// Legacy history getters for backward compatibility
  List<double> get historyX => _positionHistory.map((pos) => pos.longitude).toList();
  List<double> get historyY => _positionHistory.map((pos) => pos.latitude).toList();

  /// Affiche (console) les informations principales du bateau.
  void printInfo() {
    // ignore: avoid_print
    print('Bateau => L: $lengthMeters m | l: $beamMeters m | Tirant: $draftMeters m');
    // ignore: avoid_print
    print('Position: ($x, $y)');
    if (polars == null) {
      // ignore: avoid_print
      print('Polaires: (non chargées)');
    } else {
      // ignore: avoid_print
      print('Polaires: ${polars!.angleCount} angles x ${polars!.windCount} vents');
    }
  }
}
