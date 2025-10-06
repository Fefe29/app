/// Course state providers.
/// See ARCHITECTURE_DOCS.md (section: course_providers.dart).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';

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
    final updatedBuoys = [
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
    ];
    
    state = state.copyWith(buoys: updatedBuoys);
    
    // Synchroniser la ligne de départ si une bouée comité ou viseur a été modifiée
    _syncStartLineWithBuoys();
  }

  void setStartLine(double x1, double y1, double x2, double y2) {
    state = state.copyWith(startLine: LineSegment(p1x: x1, p1y: y1, p2x: x2, p2y: y2, type: LineType.start));
    
    // Synchroniser les bouées avec la nouvelle ligne de départ
    _syncBuoysWithStartLine();
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
      // Supprimer aussi les bouées comité et viseur associées
      final updatedBuoys = state.buoys.where((b) => 
        b.role != BuoyRole.committee && b.role != BuoyRole.target
      ).toList();
      
      state = state.copyWith(
        buoys: updatedBuoys,
        removeStart: true,
      );
    }
  }

  void removeBuoy(int id) {
    final buoyToRemove = state.buoys.where((b) => b.id == id).firstOrNull;
    
    // Si c'est une bouée comité ou viseur et qu'une ligne de départ existe,
    // supprimer la ligne de départ aussi
    if (buoyToRemove != null && 
        (buoyToRemove.role == BuoyRole.committee || buoyToRemove.role == BuoyRole.target) &&
        state.startLine != null) {
      // Supprimer toute la ligne de départ (ce qui supprimera les deux bouées)
      removeStartLine();
      return;
    }
    
    state = state.copyWith(
      buoys: state.buoys.where((b) => b.id != id).toList(),
    );
  }

  void clear() {
    _nextId = 1;
    state = CourseState.initial();
  }

  /// Synchronise la ligne de départ avec les positions actuelles des bouées comité et viseur.
  void _syncStartLineWithBuoys() {
    if (state.startLine == null) return;
    
    final targetBuoy = state.buoys.where((b) => b.role == BuoyRole.target).firstOrNull;
    final committeeBuoy = state.buoys.where((b) => b.role == BuoyRole.committee).firstOrNull;
    
    if (targetBuoy != null && committeeBuoy != null) {
      // Mettre à jour la ligne de départ sans déclencher une nouvelle synchronisation
      state = state.copyWith(
        startLine: LineSegment(
          p1x: targetBuoy.x, p1y: targetBuoy.y,  // Position du viseur
          p2x: committeeBuoy.x, p2y: committeeBuoy.y,  // Position du comité
          type: LineType.start,
        )
      );
    }
  }

  /// Synchronise les bouées comité/viseur avec la position de la ligne de départ.
  void _syncBuoysWithStartLine() {
    if (state.startLine == null) return;
    
    final targetBuoyId = state.buoys.where((b) => b.role == BuoyRole.target).firstOrNull?.id;
    final committeeBuoyId = state.buoys.where((b) => b.role == BuoyRole.committee).firstOrNull?.id;
    
    final updatedBuoys = state.buoys.map((b) {
      if (b.id == targetBuoyId) {
        // Synchroniser la position du viseur (p1 de la ligne)
        return b.copyWith(x: state.startLine!.p1x, y: state.startLine!.p1y);
      } else if (b.id == committeeBuoyId) {
        // Synchroniser la position du comité (p2 de la ligne)  
        return b.copyWith(x: state.startLine!.p2x, y: state.startLine!.p2y);
      }
      return b;
    }).toList();
    
    // Créer automatiquement les bouées si elles n'existent pas
    if (targetBuoyId == null) {
      updatedBuoys.add(Buoy(
        id: _nextId++,
        x: state.startLine!.p1x,
        y: state.startLine!.p1y,
        role: BuoyRole.target,
      ));
    }
    
    if (committeeBuoyId == null) {
      updatedBuoys.add(Buoy(
        id: _nextId++,
        x: state.startLine!.p2x,
        y: state.startLine!.p2y,
        role: BuoyRole.committee,
      ));
    }
    
    state = state.copyWith(buoys: updatedBuoys);
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
        
        // Bouée 3 à (-5, 10) - troisième bouée du parcours
        Buoy(id: 5, x: -5, y: 10, passageOrder: 3, role: BuoyRole.regular),
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