/// Modèle représentant une table de polaires.
/// angles : liste d'angles (°) en ligne  (ex: 0,5,10,...,180)
/// windSpeeds : liste de forces de vent (nds) en colonne (ex: 4,6,8,...)
/// speeds : matrice speeds[iAngle][jWind]
class PolarTable {
  PolarTable({
    required this.angles,
    required this.windSpeeds,
    required this.speeds,
  });

  final List<double> angles;
  final List<double> windSpeeds;
  final List<List<double>> speeds; // rows = angles, cols = wind speeds

  int get angleCount => angles.length;
  int get windCount => windSpeeds.length;

  /// Récupère la vitesse brute (sans interpolation) si indices valides.
  double? rawAt(int angleIndex, int windIndex) {
    if (angleIndex < 0 || angleIndex >= angleCount) return null;
    if (windIndex < 0 || windIndex >= windCount) return null;
    return speeds[angleIndex][windIndex];
  }

  /// Cherche l'indice de l'angle le plus proche (recherche linéaire simple pour taille modeste).
  int nearestAngleIndex(double angleDeg) {
    if (angles.isEmpty) return -1;
    double bestDiff = double.infinity;
    int best = 0;
    for (var i = 0; i < angles.length; i++) {
      final d = (angles[i] - angleDeg).abs();
      if (d < bestDiff) {
        bestDiff = d;
        best = i;
      }
    }
    return best;
  }

  /// Cherche l'indice de la force de vent la plus proche.
  int nearestWindIndex(double wind) {
    if (windSpeeds.isEmpty) return -1;
    double bestDiff = double.infinity;
    int best = 0;
    for (var i = 0; i < windSpeeds.length; i++) {
      final d = (windSpeeds[i] - wind).abs();
      if (d < bestDiff) {
        bestDiff = d;
        best = i;
      }
    }
    return best;
  }

  /// Renvoie la vitesse via nearest neighbour (MVP).
  double? nearest(double angleDeg, double wind) {
    final ai = nearestAngleIndex(angleDeg.abs());
    final wi = nearestWindIndex(wind.abs());
    if (ai == -1 || wi == -1) return null;
    return rawAt(ai, wi);
  }
}

/// Résultat d'un calcul VMC / VMG optimum.
class VmcResult {
  VmcResult({required this.angleDeg, required this.speed, required this.vmg});
  final double angleDeg; // angle par rapport au vent (0 = face au vent, 180 = plein vent arrière)
  final double speed; // vitesse du bateau (nds)
  final double vmg; // composante vers (près) ou sous (portant) le vent, nds
}
