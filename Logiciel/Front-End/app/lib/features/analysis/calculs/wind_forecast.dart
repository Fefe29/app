/// Fonctions pour la prévision court-terme (EMA, Kalman, ARIMA, HMM, régression, etc.)
/// Implémentations simplifiées pour embarqué

/// EMA + Kalman simplifié pour TWD/TWS
List<double> kalman1D(List<double> measurements, double q, double r) {
  // q: process noise, r: measurement noise
  double x = measurements.first;
  double p = 1.0;
  List<double> result = [x];
  for (int i = 1; i < measurements.length; i++) {
    // Prediction
    p += q;
    // Update
    double k = p / (p + r);
    x += k * (measurements[i] - x);
    p *= (1 - k);
    result.add(x);
  }
  return result;
}

// ARIMA, HMM, FFT, régression à ajouter selon besoins...
