/// Transposition de `Girouette_anemo_simu.py` en Dart (sans provider Riverpod pour l'instant).
///
/// Objectif: reproduire la logique des fonctions `vent_t` et `vent` qui simulent
/// un vent discret avec différents modes de régularité et "bascule".
///
/// Différences / Adaptations:
/// - Le code Python écrivait dans un fichier `wind_doc.txt`; ici on expose un
///   callback optionnel `onSample` (ou on peut simplement collecter l'historique).
/// - Le bruit gaussien est généré via Box-Muller (Random().nextDouble()).
/// - Les petites variations (sigma=0.01) sont conservées telles quelles pour rester fidèle,
///   même si en degrés cela est très faible; vous pouvez augmenter les sigmas si besoin.
/// - Le pas temporel est géré par `tick()` explicite (aucun Timer interne) pour laisser
///   le choix d'intégrer ce simulateur dans un scheduler existant plus tard.
/// - `bascule` accepte: "gauche", "droite", "imprevisible" ou null.
/// - Incrémente/décrémente la direction de 0.01 par tick si bascule gauche/droite.
///
/// Usage de base:
/// ```dart
/// final sim = WindSimulator(directionDeg: 45, force: 8);
/// final sample = sim.tick(); // retourne un WindInstant
/// ```
import 'dart:math' as math;

class WindInstant {
  WindInstant({required this.directionDeg, required this.force, required this.baseDirectionDeg});
  final double directionDeg; // direction instantanée générée
  final double force; // force instantanée (ex: nds)
  final double baseDirectionDeg; // direction moyenne mise à jour (direction_moy_new)

  @override
  String toString() => 'WindInstant(dir=${directionDeg.toStringAsFixed(3)}°, force=${force.toStringAsFixed(3)}, base=${baseDirectionDeg.toStringAsFixed(3)})';
}

class WindSimulatorConfig {
  const WindSimulatorConfig({
    this.directionMoyenneReguliere = false,
    this.forceReguliere = false,
    this.bascule,
    this.sigmaDirection = 0.01,
    this.sigmaForce = 0.01,
    this.sigmaDirectionImprevisible = 10.0,
    this.sigmaForceImprevisible = 0.5,
    this.shiftIncrement = 0.01, // valeur ajoutée / retranchée par tick si bascule gauche/droite
  });

  final bool directionMoyenneReguliere;
  final bool forceReguliere;
  final String? bascule; // 'gauche' | 'droite' | 'imprevisible' | null
  final double sigmaDirection;
  final double sigmaForce;
  final double sigmaDirectionImprevisible;
  final double sigmaForceImprevisible;
  final double shiftIncrement;

  WindSimulatorConfig copyWith({
    bool? directionMoyenneReguliere,
    bool? forceReguliere,
    String? bascule,
    double? sigmaDirection,
    double? sigmaForce,
    double? sigmaDirectionImprevisible,
    double? sigmaForceImprevisible,
    double? shiftIncrement,
  }) => WindSimulatorConfig(
        directionMoyenneReguliere: directionMoyenneReguliere ?? this.directionMoyenneReguliere,
        forceReguliere: forceReguliere ?? this.forceReguliere,
        bascule: bascule ?? this.bascule,
        sigmaDirection: sigmaDirection ?? this.sigmaDirection,
        sigmaForce: sigmaForce ?? this.sigmaForce,
        sigmaDirectionImprevisible: sigmaDirectionImprevisible ?? this.sigmaDirectionImprevisible,
        sigmaForceImprevisible: sigmaForceImprevisible ?? this.sigmaForceImprevisible,
        shiftIncrement: shiftIncrement ?? this.shiftIncrement,
      );
}

class WindSimulator {
  WindSimulator({
    required double directionDeg,
    required double force,
    WindSimulatorConfig config = const WindSimulatorConfig(),
    void Function(WindInstant)? onSample,
  })  : _directionBase = directionDeg,
        _forceBase = force,
        _config = config,
        _onSample = onSample,
        _rng = math.Random();

  final WindSimulatorConfig _config;
  final void Function(WindInstant)? _onSample;
  final math.Random _rng;

  double _directionBase; // direction moyenne sur laquelle s'applique le bruit
  double _forceBase; // force moyenne

  /// Générateur gaussien (Box-Muller) renvoyant moyenne=mu, sigma=sigma.
  double _gauss(double mu, double sigma) {
    // Protection sigma <= 0
    if (sigma <= 0) return mu;
    final u1 = _rng.nextDouble().clamp(1e-12, 1 - 1e-12);
    final u2 = _rng.nextDouble().clamp(1e-12, 1 - 1e-12);
    final mag = math.sqrt(-2.0 * math.log(u1));
    final z0 = mag * math.cos(2 * math.pi * u2);
    return mu + z0 * sigma;
  }

  /// Avance d'un tick et retourne un échantillon de vent.
  WindInstant tick() {
    final c = _config;
    double directionT;
    double forceT;
    double directionMoyNew = _directionBase; // par défaut

    try {
      if (!c.directionMoyenneReguliere && !c.forceReguliere) {
        // irrégulier direction + force
        directionT = _gauss(_directionBase, c.sigmaDirection);
        forceT = _gauss(_forceBase, c.sigmaForce);
        if (c.bascule == 'gauche') {
          directionT -= c.shiftIncrement;
          directionMoyNew = directionT;
        } else if (c.bascule == 'droite') {
          directionT += c.shiftIncrement;
          directionMoyNew = directionT;
        }
      } else if (!c.directionMoyenneReguliere && c.forceReguliere) {
        // irrégulier direction / force régulière
        directionT = _gauss(_directionBase, c.sigmaDirection);
        forceT = _forceBase;
        if (c.bascule == 'gauche') {
          directionT -= c.shiftIncrement;
          directionMoyNew = directionT;
        } else if (c.bascule == 'droite') {
          directionT += c.shiftIncrement;
          directionMoyNew = directionT;
        }
      } else if (c.directionMoyenneReguliere && c.forceReguliere) {
        // régulier direction + force (mais code Python mettait qd même bruit fin)
        directionT = _gauss(_directionBase, c.sigmaDirection);
        forceT = _gauss(_forceBase, c.sigmaForce);
        if (c.bascule == 'imprevisible') {
          directionT = _gauss(_directionBase, c.sigmaDirectionImprevisible);
          forceT = _forceBase; // force stable
        }
      } else {
        // direction régulière / force irrégulière
        directionT = _gauss(_directionBase, c.sigmaDirection);
        forceT = _gauss(_forceBase, c.sigmaForce);
        if (c.bascule == 'imprevisible') {
          directionT = _gauss(_directionBase, c.sigmaDirectionImprevisible);
          forceT = _gauss(_forceBase, c.sigmaForceImprevisible);
        }
      }
    } catch (e) {
      // fallback en cas d'erreur inattendue
      directionT = _directionBase;
      forceT = _forceBase;
    }

    // Mise à jour de la base si elle a changé
    _directionBase = directionMoyNew;

    final sample = WindInstant(
      directionDeg: _normalizeDirection(directionT),
      force: forceT,
      baseDirectionDeg: _normalizeDirection(_directionBase),
    );
    _onSample?.call(sample);
    return sample;
  }

  /// Normalisation 0..360 (optionnelle)
  double _normalizeDirection(double d) {
    var val = d % 360.0;
    if (val < 0) val += 360.0;
    return val;
  }

  double get directionBase => _directionBase;
  double get forceBase => _forceBase;

  void setDirectionBase(double d) => _directionBase = d;
  void setForceBase(double f) => _forceBase = f;

  WindSimulator copyWith({double? directionBase, double? forceBase, WindSimulatorConfig? config, void Function(WindInstant)? onSample}) {
    final sim = WindSimulator(
      directionDeg: directionBase ?? _directionBase,
      force: forceBase ?? _forceBase,
      config: config ?? _config,
      onSample: onSample ?? _onSample,
    );
    return sim;
  }
}
