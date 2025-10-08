import 'geographic_position.dart';

enum BuoyRole { regular, committee, target }

class Buoy {
  Buoy({
    required this.id,
    required this.position,
    this.passageOrder,
    this.role = BuoyRole.regular,
  });
  
  final int id; // simple incremental id
  final GeographicPosition position; // Position géographique (latitude, longitude)
  final int? passageOrder; // ordre de passage (1,2,3...) éventuellement
  final BuoyRole role; // rôle spécifique (parcours, comité, viseur)

  /// Legacy getters for compatibility with existing code
  double get x => tempLocalPos?.x ?? 0.0;
  double get y => tempLocalPos?.y ?? 0.0;
  
  /// Temporary local position for backward compatibility during migration
  LocalPosition? tempLocalPos;
  
  /// Constructor for legacy x/y coordinates (will be removed after migration)
  Buoy.legacy({
    required this.id,
    required double x,
    required double y,
    this.passageOrder,
    this.role = BuoyRole.regular,
  }) : position = const GeographicPosition(latitude: 0, longitude: 0),
       tempLocalPos = LocalPosition(x: x, y: y);

  Buoy copyWith({
    int? id,
    GeographicPosition? position,
    double? x,
    double? y,
    int? passageOrder = _noIntSentinel,
    BuoyRole? role,
  }) {
    GeographicPosition newPosition = position ?? this.position;
    LocalPosition? newTempLocal = tempLocalPos;
    
    // Handle legacy x/y parameters
    if (x != null || y != null) {
      newTempLocal = LocalPosition(
        x: x ?? this.x,
        y: y ?? this.y,
      );
    }
    
    final result = Buoy(
      id: id ?? this.id,
      position: newPosition,
      passageOrder: passageOrder == _noIntSentinel ? this.passageOrder : passageOrder,
      role: role ?? this.role,
    );
    
    result.tempLocalPos = newTempLocal;
    return result;
  }

  static const int _noIntSentinel = -9999999; // interne pour différencier null explicite
}

enum LineType { start, finish }

class LineSegment {
  LineSegment({
    required this.point1,
    required this.point2,
    required this.type,
  });
  
  final GeographicPosition point1;
  final GeographicPosition point2;
  final LineType type;

  /// Legacy getters for compatibility with existing code
  double get p1x => tempLocalP1?.x ?? 0.0;
  double get p1y => tempLocalP1?.y ?? 0.0;
  double get p2x => tempLocalP2?.x ?? 0.0;
  double get p2y => tempLocalP2?.y ?? 0.0;
  
  /// Temporary local positions for backward compatibility during migration
  LocalPosition? tempLocalP1;
  LocalPosition? tempLocalP2;
  
  /// Constructor for legacy x/y coordinates (will be removed after migration)
  LineSegment.legacy({
    required double p1x,
    required double p1y,
    required double p2x,
    required double p2y,
    required this.type,
  }) : point1 = const GeographicPosition(latitude: 0, longitude: 0),
       point2 = const GeographicPosition(latitude: 0, longitude: 0),
       tempLocalP1 = LocalPosition(x: p1x, y: p1y),
       tempLocalP2 = LocalPosition(x: p2x, y: p2y);
}

class CourseState {
  CourseState({required this.buoys, this.startLine, this.finishLine});
  final List<Buoy> buoys;
  final LineSegment? startLine;
  final LineSegment? finishLine;

  CourseState copyWith({
    List<Buoy>? buoys,
    LineSegment? startLine,
    LineSegment? finishLine,
    bool removeStart = false,
    bool removeFinish = false,
  }) => CourseState(
        buoys: buoys ?? this.buoys,
        startLine: removeStart ? null : (startLine ?? this.startLine),
        finishLine: removeFinish ? null : (finishLine ?? this.finishLine),
      );

  static CourseState initial() => CourseState(buoys: []);
}