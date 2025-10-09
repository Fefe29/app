/// Provider de migration pour passer progressivement au système Mercator
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'coordinate_system_provider.dart';
import 'mercator_coordinate_system_provider.dart';
import '../domain/models/geographic_position.dart';

/// Indicateur du système de coordonnées actuel
enum CoordinateSystem { legacy, mercator }

/// Configuration de migration entre les systèmes de coordonnées
class MigrationConfig {
  const MigrationConfig({
    required this.activeSystem,
    required this.autoMigrate,
  });

  final CoordinateSystem activeSystem;
  final bool autoMigrate; // Migration automatique vers Mercator

  MigrationConfig copyWith({
    CoordinateSystem? activeSystem,
    bool? autoMigrate,
  }) => MigrationConfig(
        activeSystem: activeSystem ?? this.activeSystem,
        autoMigrate: autoMigrate ?? this.autoMigrate,
      );
}

/// Notifier pour gérer la migration entre systèmes de coordonnées
class CoordinateMigrationNotifier extends Notifier<MigrationConfig> {
  @override
  MigrationConfig build() {
    return const MigrationConfig(
      activeSystem: CoordinateSystem.mercator, // Par défaut, utiliser Mercator
      autoMigrate: true,
    );
  }

  /// Active le système Mercator
  void enableMercator() {
    state = state.copyWith(activeSystem: CoordinateSystem.mercator);
  }

  /// Revient au système legacy (pour debug)
  void enableLegacy() {
    state = state.copyWith(activeSystem: CoordinateSystem.legacy);
  }

  /// Active/désactive la migration automatique
  void setAutoMigrate(bool enabled) {
    state = state.copyWith(autoMigrate: enabled);
  }
}

/// Provider pour la configuration de migration
final coordinateMigrationProvider = NotifierProvider<CoordinateMigrationNotifier, MigrationConfig>(() {
  return CoordinateMigrationNotifier();
});

/// Service unifié qui utilise le bon système selon la configuration de migration
class UnifiedCoordinateService {
  UnifiedCoordinateService({
    required this.legacyService,
    required this.mercatorService,
    required this.migrationConfig,
  });

  final CoordinateSystemService legacyService;
  final MercatorCoordinateSystemService mercatorService;
  final MigrationConfig migrationConfig;

  /// Convertit position géographique vers coordonnées locales
  LocalPosition toLocal(GeographicPosition geo) {
    switch (migrationConfig.activeSystem) {
      case CoordinateSystem.legacy:
        return legacyService.toLocal(geo);
      case CoordinateSystem.mercator:
        return mercatorService.toLocal(geo);
    }
  }

  /// Convertit coordonnées locales vers position géographique
  GeographicPosition toGeographic(LocalPosition local) {
    switch (migrationConfig.activeSystem) {
      case CoordinateSystem.legacy:
        return legacyService.toGeographic(local);
      case CoordinateSystem.mercator:
        return mercatorService.toGeographic(local);
    }
  }

  /// Calcule la distance entre deux positions
  double distanceMeters(GeographicPosition pos1, GeographicPosition pos2) {
    switch (migrationConfig.activeSystem) {
      case CoordinateSystem.legacy:
        return legacyService.distanceMeters(pos1, pos2);
      case CoordinateSystem.mercator:
        return mercatorService.distanceMeters(pos1, pos2);
    }
  }

  /// Calcule le bearing entre deux positions
  double bearingDegrees(GeographicPosition pos1, GeographicPosition pos2) {
    switch (migrationConfig.activeSystem) {
      case CoordinateSystem.legacy:
        return legacyService.bearingDegrees(pos1, pos2);
      case CoordinateSystem.mercator:
        return mercatorService.bearingDegrees(pos1, pos2);
    }
  }

  /// Convertit tuile vers coordonnées locales (seulement disponible avec Mercator)
  LocalPosition? tileToLocal(int tileX, int tileY, int zoom) {
    if (migrationConfig.activeSystem == CoordinateSystem.mercator) {
      return mercatorService.tileToLocal(tileX, tileY, zoom);
    }
    return null; // Pas supporté par le système legacy
  }

  /// Indique si on utilise Mercator
  bool get isMercator => migrationConfig.activeSystem == CoordinateSystem.mercator;

  /// Nom du système actuel
  String get systemName => migrationConfig.activeSystem == CoordinateSystem.mercator ? 'Mercator' : 'Legacy';
}

/// Provider pour le service unifié
final unifiedCoordinateServiceProvider = Provider<UnifiedCoordinateService>((ref) {
  final legacyService = ref.watch(coordinateSystemProvider);
  final mercatorService = ref.watch(mercatorCoordinateSystemProvider);
  final migrationConfig = ref.watch(coordinateMigrationProvider);

  return UnifiedCoordinateService(
    legacyService: legacyService,
    mercatorService: mercatorService,
    migrationConfig: migrationConfig,
  );
});