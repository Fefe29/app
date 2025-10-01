/// Transposition de la classe `Bateau` (Bateau.py) en Dart.
/// Fournit un conteneur simple pour les caractéristiques physiques
/// et la table de polaires associée.
/// \n
import 'polar_table.dart';

class Boat {
  Boat({
    required this.lengthMeters,
    required this.beamMeters,
    required this.draftMeters,
    required this.x,
    required this.y,
    required this.polars,
  });

  double lengthMeters; // Longueur
  double beamMeters; // Largeur
  double draftMeters; // Tirant d'eau

  double x; // Coordonnée X courante
  double y; // Coordonnée Y courante

  final PolarTable? polars; // Peut être null si non chargé

  final List<double> _historyX = [];
  final List<double> _historyY = [];

  /// Enregistre la position actuelle dans l'historique.
  void snapshotPosition() {
    _historyX.add(x);
    _historyY.add(y);
  }

  /// Met à jour la position et garde une trace historique (optionnel).
  void moveTo(double newX, double newY, {bool record = true}) {
    x = newX;
    y = newY;
    if (record) snapshotPosition();
  }

  /// Retourne les coordonnées courantes.
  List<double> get position => [x, y];

  /// Historique X (copie non modifiable).
  List<double> get historyX => List.unmodifiable(_historyX);

  /// Historique Y (copie non modifiable).
  List<double> get historyY => List.unmodifiable(_historyY);

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
