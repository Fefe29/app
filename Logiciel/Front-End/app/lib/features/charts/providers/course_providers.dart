/// Course state providers.
/// See ARCHITECTURE_DOCS.md (section: course_providers.dart).
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/course.dart';

class CourseNotifier extends Notifier<CourseState> {
  int _nextId = 6; // Commencer après les IDs du parcours de test (1-5)
  @override
  CourseState build() => _createTestCourse();

  void addBuoy(double x, double y, {int? passageOrder, BuoyRole role = BuoyRole.regular}) {
    state = state.copyWith(
      buoys: [
        ...state.buoys,
        Buoy(id: _nextId++, x: x, y: y, passageOrder: passageOrder, role: role),
      ],
    );
  }

  void updateBuoy(
    int id, {
    double? x,
    double? y,
    int? passageOrder,
    BuoyRole? role,
  }) {
    state = state.copyWith(
      buoys: [
        for (final b in state.buoys)
          if (b.id == id)
            b.copyWith(
              x: x,
              y: y,
              // On passe directement passageOrder; la logique sentinel est interne à la classe
              passageOrder: passageOrder,
              role: role,
            )
          else
            b,
      ],
    );
  }

  void setStartLine(double x1, double y1, double x2, double y2) {
    state = state.copyWith(startLine: LineSegment(p1x: x1, p1y: y1, p2x: x2, p2y: y2, type: LineType.start));
  }

  void setFinishLine(double x1, double y1, double x2, double y2) {
    state = state.copyWith(finishLine: LineSegment(p1x: x1, p1y: y1, p2x: x2, p2y: y2, type: LineType.finish));
  }

  void removeFinishLine() {
    if (state.finishLine != null) {
      state = state.copyWith(removeFinish: true);
    }
  }

  void removeStartLine() {
    if (state.startLine != null) {
      state = state.copyWith(removeStart: true);
    }
  }

  void removeBuoy(int id) {
    state = state.copyWith(
      buoys: state.buoys.where((b) => b.id != id).toList(),
    );
  }

  void clear() {
    _nextId = 1;
    state = CourseState.initial();
  }

  /// Crée un parcours de test pour valider le routing et les laylines.
  /// TODO: Supprimer cette méthode après les tests et revenir à CourseState.initial()
  CourseState _createTestCourse() {
    return CourseState(
      buoys: [
        // Bouée 1 à (0, 50) - au près face au vent (vent ~315°)
        Buoy(id: 1, x: 0, y: 50, passageOrder: 1, role: BuoyRole.regular),
        
        // Viseur à (20, 0) - pour ciblage tactique
        Buoy(id: 2, x: 20, y: 0, role: BuoyRole.target),
        
        // Comité à (30, 0) - bouée de départ/comité de course
        Buoy(id: 3, x: 30, y: 0, role: BuoyRole.committee),
        
        // Bouée 2 à (-20, 50) - deuxième bouée du parcours
        Buoy(id: 4, x: -20, y: 50, passageOrder: 2, role: BuoyRole.regular),
        
        // Bouée 3 à (-20, 0) - troisième bouée du parcours
        Buoy(id: 5, x: -20, y: 0, passageOrder: 3, role: BuoyRole.regular),
      ],
      // Ligne de départ entre viseur (20, 0) et comité (30, 0)
      startLine: LineSegment(
        p1x: 20, p1y: 0,  // Position du viseur
        p2x: 30, p2y: 0,  // Position du comité
        type: LineType.start,
      ),
      // Ligne d'arrivée près de la bouée 3
      finishLine: LineSegment(
        p1x: -25, p1y: -5,
        p2x: -15, p2y: -5,
        type: LineType.finish,
      ),
    );
  }
}

final courseProvider = NotifierProvider<CourseNotifier, CourseState>(CourseNotifier.new);