/// Fonctions pour les indicateurs orientés performance (VMG, polaire, laylines dynamiques, etc.)

/// Variation de VMG expliquée par le vent
List<double> vmgChangeByWind(List<double> vmg, List<double> twd, List<double> tws) {
  // d(VMG)/d(TWD), d(VMG)/d(TWS)
  List<double> dVmgTwd = [];
  List<double> dVmgTws = [];
  for (int i = 1; i < vmg.length; i++) {
    dVmgTwd.add((vmg[i] - vmg[i - 1]) / (twd[i] - twd[i - 1]));
    dVmgTws.add((vmg[i] - vmg[i - 1]) / (tws[i] - tws[i - 1]));
  }
  return [dVmgTwd.isNotEmpty ? dVmgTwd.last : 0.0, dVmgTws.isNotEmpty ? dVmgTws.last : 0.0];
}

/// Gain/perte polaire (écart à la polaire avant/après shift)
double polarGain(double boatspeed, double targetBoatspeed) {
  return boatspeed - targetBoatspeed;
}

// Laylines dynamiques, suggestions trim, etc. à ajouter...
