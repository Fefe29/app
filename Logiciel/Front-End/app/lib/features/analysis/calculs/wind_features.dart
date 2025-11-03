/// Fonctions pour extraire les features utiles à l'IA (fenêtres glissantes, stats, etc.)

/// Fenêtre glissante sur une liste
dynamic slidingWindow(List<dynamic> data, int window) {
  if (data.length < window) return [];
  List<dynamic> result = [];
  for (int i = 0; i <= data.length - window; i++) {
    result.add(data.sublist(i, i + window));
  }
  return result;
}

// Ajoute extraction de features : skew, kurtosis, U/V, etc. au besoin...
