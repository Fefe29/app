/// Course state providers.
/// See ARCHITECTURE_DOCS.md (section: course_providers.dart).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';

import '../domain/models/course.dart';
import '../domain/models/geographic_position.dart';

class CourseNotifier extends Notifier<CourseState> {
  int _nextId = 6; // Commencer après les IDs du parcours de test (1-5)
  @override
  CourseState build() => _createTestCourse();

  // Legacy method for backward compatibility
  void addBuoy(double x, double y, {int? passageOrder, BuoyRole role = BuoyRole.regular}) {
    state = state.copyWith(
      buoys: [
        ...state.buoys,
        Buoy.legacy(id: _nextId++, x: x, y: y, passageOrder: passageOrder, role: role),
      ],
    );
  }

  // New method using geographic coordinates
  void addBuoyGeographic(GeographicPosition position, {int? passageOrder, BuoyRole role = BuoyRole.regular}) {
    state = state.copyWith(
      buoys: [
        ...state.buoys,
        Buoy(id: _nextId++, position: position, passageOrder: passageOrder, role: role),
      ],
    );
  }

  // Legacy method for backward compatibility
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

  // New method using geographic coordinates
  void updateBuoyGeographic(
    int id, {
    GeographicPosition? position,
    int? passageOrder,
    BuoyRole? role,
  }) {
    final updatedBuoys = [
      for (final b in state.buoys)
        if (b.id == id)
          Buoy(
            id: b.id,
            position: position ?? b.position,
            passageOrder: passageOrder ?? b.passageOrder,
            role: role ?? b.role,
          )
        else
          b,
    ];
    
    state = state.copyWith(buoys: updatedBuoys);
    
    // Synchroniser la ligne de départ si une bouée comité ou viseur a été modifiée
    _syncStartLineWithBuoysGeographic();
  }

  // Legacy method for backward compatibility  
  void setStartLine(double x1, double y1, double x2, double y2) {
    state = state.copyWith(startLine: LineSegment.legacy(p1x: x1, p1y: y1, p2x: x2, p2y: y2, type: LineType.start));
    
    // Synchroniser les bouées avec la nouvelle ligne de départ
    _syncBuoysWithStartLine();
  }

  // Legacy method for backward compatibility
  void setFinishLine(double x1, double y1, double x2, double y2) {
    state = state.copyWith(finishLine: LineSegment.legacy(p1x: x1, p1y: y1, p2x: x2, p2y: y2, type: LineType.finish));
  }

  // New methods using geographic coordinates
  void setStartLineGeographic(GeographicPosition point1, GeographicPosition point2) {
    state = state.copyWith(startLine: LineSegment(point1: point1, point2: point2, type: LineType.start));
    
    // Synchroniser les bouées avec la nouvelle ligne de départ
    _syncBuoysWithStartLineGeographic();
  }

  void setFinishLineGeographic(GeographicPosition point1, GeographicPosition point2) {
    state = state.copyWith(finishLine: LineSegment(point1: point1, point2: point2, type: LineType.finish));
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

  /// Synchronise la ligne de départ avec les positions actuelles des bouées comité et viseur (legacy).
  void _syncStartLineWithBuoys() {
    if (state.startLine == null) return;
    
    final targetBuoy = state.buoys.where((b) => b.role == BuoyRole.target).firstOrNull;
    final committeeBuoy = state.buoys.where((b) => b.role == BuoyRole.committee).firstOrNull;
    
    if (targetBuoy != null && committeeBuoy != null) {
      // Mettre à jour la ligne de départ sans déclencher une nouvelle synchronisation
      state = state.copyWith(
        startLine: LineSegment.legacy(
          p1x: targetBuoy.x, p1y: targetBuoy.y,  // Position du viseur
          p2x: committeeBuoy.x, p2y: committeeBuoy.y,  // Position du comité
          type: LineType.start,
        )
      );
    }
  }

  /// Synchronise la ligne de départ avec les positions géographiques des bouées comité et viseur.
  void _syncStartLineWithBuoysGeographic() {
    if (state.startLine == null) return;
    
    final targetBuoy = state.buoys.where((b) => b.role == BuoyRole.target).firstOrNull;
    final committeeBuoy = state.buoys.where((b) => b.role == BuoyRole.committee).firstOrNull;
    
    if (targetBuoy != null && committeeBuoy != null) {
      // Mettre à jour la ligne de départ avec les positions géographiques
      state = state.copyWith(
        startLine: LineSegment(
          point1: targetBuoy.position,  // Position du viseur
          point2: committeeBuoy.position,  // Position du comité
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
      updatedBuoys.add(Buoy.legacy(
        id: _nextId++,
        x: state.startLine!.p1x,
        y: state.startLine!.p1y,
        role: BuoyRole.target,
      ));
    }
    
    if (committeeBuoyId == null) {
      updatedBuoys.add(Buoy.legacy(
        id: _nextId++,
        x: state.startLine!.p2x,
        y: state.startLine!.p2y,
        role: BuoyRole.committee,
      ));
    }
    
    state = state.copyWith(buoys: updatedBuoys);
  }

  /// Synchronise les bouées comité/viseur avec la position géographique de la ligne de départ.
  void _syncBuoysWithStartLineGeographic() {
    if (state.startLine == null) return;
    
    final targetBuoyId = state.buoys.where((b) => b.role == BuoyRole.target).firstOrNull?.id;
    final committeeBuoyId = state.buoys.where((b) => b.role == BuoyRole.committee).firstOrNull?.id;
    
    final updatedBuoys = state.buoys.map((b) {
      if (b.id == targetBuoyId) {
        // Synchroniser la position du viseur (point1 de la ligne)
        return Buoy(id: b.id, position: state.startLine!.point1, passageOrder: b.passageOrder, role: b.role);
      } else if (b.id == committeeBuoyId) {
        // Synchroniser la position du comité (point2 de la ligne)  
        return Buoy(id: b.id, position: state.startLine!.point2, passageOrder: b.passageOrder, role: b.role);
      }
      return b;
    }).toList();
    
    // Créer automatiquement les bouées si elles n'existent pas
    if (targetBuoyId == null) {
      updatedBuoys.add(Buoy(
        id: _nextId++,
        position: state.startLine!.point1,
        role: BuoyRole.target,
      ));
    }
    
    if (committeeBuoyId == null) {
      updatedBuoys.add(Buoy(
        id: _nextId++,
        position: state.startLine!.point2,
        role: BuoyRole.committee,
      ));
    }
    
    state = state.copyWith(buoys: updatedBuoys);
  }

  /// Crée un parcours de test géographique réaliste en Méditerranée (baie de Cannes).
  /// Parcours olympique triangulaire avec vraies coordonnées géographiques.
  CourseState _createTestCourse() {
    // Coordonnées réelles dans la baie de Cannes (43.5°N, 7.0°E environ)
    
    return CourseState(
      buoys: [
        // Bouée 1 - Marque au vent (500m au nord)
        Buoy(
          id: 1, 
          position: const GeographicPosition(latitude: 43.548, longitude: 7.000), 
          passageOrder: 1, 
          role: BuoyRole.regular
        ),
        
        // Viseur - Extrémité tribord de la ligne de départ
        Buoy(
          id: 2, 
          position: const GeographicPosition(latitude: 43.5400, longitude: 7.0120), 
          role: BuoyRole.target
        ),
        
        // Comité - Extrémité bâbord de la ligne de départ  
        Buoy(
          id: 3, 
          position: const GeographicPosition(latitude: 43.5430, longitude: 7.0180), 
          role: BuoyRole.committee
        ),
        
        // Bouée 2 - Marque sous le vent bâbord (600m au sud-ouest)
        Buoy(
          id: 4, 
          position: const GeographicPosition(latitude: 43.53606, longitude: 7.010), 
          passageOrder: 2, 
          role: BuoyRole.regular
        ),
        
        // Bouée 3 - Marque sous le vent tribord (600m au sud-est)
        Buoy(
          id: 5, 
          position: const GeographicPosition(latitude: 43.53606, longitude: 7.0210), 
          passageOrder: 3, 
          role: BuoyRole.regular
        ),
      ],
      // Ligne de départ entre viseur et comité (ligne de 400m est-ouest)
      startLine: LineSegment(
        point1: const GeographicPosition(latitude: 43.540, longitude: 7.0120), // Viseur (tribord)
        point2: const GeographicPosition(latitude: 43.543, longitude: 7.0180), // Comité (bâbord)
        type: LineType.start,
      ),
      // Ligne d'arrivée
      finishLine: LineSegment(
        point1: const GeographicPosition(latitude: 43.539, longitude: 7.020), 
        point2: const GeographicPosition(latitude: 43.539, longitude: 7.023),
        type: LineType.finish,
      ),
    );
  }
}

final courseProvider = NotifierProvider<CourseNotifier, CourseState>(CourseNotifier.new);