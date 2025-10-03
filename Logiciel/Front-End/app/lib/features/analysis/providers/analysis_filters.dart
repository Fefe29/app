/// Analysis filters provider definitions.
/// See ARCHITECTURE_DOCS.md (section: analysis_filters.dart).
// lib/features/analysis/analysis_filters.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class AnalysisFilters {
  final bool twd;
  final bool tws;
  final bool twa;
  final bool boatSpeed;
  final bool polars;

  const AnalysisFilters({
    this.twd = true,
    this.tws = true,
    this.twa = true,
    this.boatSpeed = true,
    this.polars = false,
  });

  AnalysisFilters copyWith({
    bool? twd,
    bool? tws,
    bool? twa,
    bool? boatSpeed,
    bool? polars,
  }) {
    return AnalysisFilters(
      twd: twd ?? this.twd,
      tws: tws ?? this.tws,
      twa: twa ?? this.twa,
      boatSpeed: boatSpeed ?? this.boatSpeed,
      polars: polars ?? this.polars,
    );
  }
}

class AnalysisFiltersNotifier extends Notifier<AnalysisFilters> {
  @override
  AnalysisFilters build() => const AnalysisFilters();

  // setters rapides
  void set({
    bool? twd,
    bool? tws,
    bool? twa,
    bool? boatSpeed,
    bool? polars,
  }) {
    state = state.copyWith(
      twd: twd,
      tws: tws,
      twa: twa,
      boatSpeed: boatSpeed,
      polars: polars,
    );
  }

  // toggles pratiques
  void toggleTwd() => state = state.copyWith(twd: !state.twd);
  void toggleTws() => state = state.copyWith(tws: !state.tws);
  void toggleTwa() => state = state.copyWith(twa: !state.twa);
  void toggleBoatSpeed() => state = state.copyWith(boatSpeed: !state.boatSpeed);
  void togglePolars() => state = state.copyWith(polars: !state.polars);
}

final analysisFiltersProvider =
    NotifierProvider<AnalysisFiltersNotifier, AnalysisFilters>(
  AnalysisFiltersNotifier.new,
);
