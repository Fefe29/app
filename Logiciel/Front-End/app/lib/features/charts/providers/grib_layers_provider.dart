import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/datasources/gribs/grib_downloader.dart';

/// Notifier pour afficher/masquer les GRIBs sur la carte
class GribVisibilityNotifier extends Notifier<bool> {
  @override
  bool build() => true;
  void setVisible(bool v) => state = v;
}

final gribVisibilityProvider = NotifierProvider<GribVisibilityNotifier, bool>(GribVisibilityNotifier.new);

class GribLayerSelection {
  final GribModel model;
  final Set<GribVariable> variables;
  final bool isVisible;

  GribLayerSelection({
    required this.model,
    required this.variables,
    this.isVisible = true,
  });

  GribLayerSelection copyWith({
    GribModel? model,
    Set<GribVariable>? variables,
    bool? isVisible,
  }) => GribLayerSelection(
    model: model ?? this.model,
    variables: variables ?? this.variables,
    isVisible: isVisible ?? this.isVisible,
  );
}

class GribLayersState {
  final List<GribLayerSelection> selections;

  GribLayersState({required this.selections});

  GribLayersState copyWith({List<GribLayerSelection>? selections}) =>
      GribLayersState(selections: selections ?? this.selections);
}

class GribLayersNotifier extends Notifier<GribLayersState> {
  @override
  GribLayersState build() {
    // Par défaut, aucune couche sélectionnée
    return GribLayersState(selections: []);
  }

  void toggleLayer(GribModel model, GribVariable variable, {bool? visible}) {
    final idx = state.selections.indexWhere((s) => s.model == model);
    if (idx == -1) {
      state = state.copyWith(selections: [
        ...state.selections,
        GribLayerSelection(model: model, variables: {variable}, isVisible: visible ?? true),
      ]);
    } else {
      final sel = state.selections[idx];
      final vars = Set<GribVariable>.from(sel.variables);
      if (vars.contains(variable)) {
        vars.remove(variable);
      } else {
        vars.add(variable);
      }
      state = state.copyWith(selections: [
        ...state.selections..removeAt(idx),
        sel.copyWith(variables: vars, isVisible: visible ?? sel.isVisible),
      ]);
    }
  }

  void setLayerVisibility(GribModel model, bool visible) {
    final idx = state.selections.indexWhere((s) => s.model == model);
    if (idx != -1) {
      final sel = state.selections[idx];
      state = state.copyWith(selections: [
        ...state.selections..removeAt(idx),
        sel.copyWith(isVisible: visible),
      ]);
    }
  }

  void clear() {
    state = GribLayersState(selections: []);
  }
}

final gribLayersProvider = NotifierProvider<GribLayersNotifier, GribLayersState>(() => GribLayersNotifier());
