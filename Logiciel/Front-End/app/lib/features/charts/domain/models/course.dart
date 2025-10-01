enum BuoyRole { regular, committee, target }

class Buoy {
  Buoy({
    required this.id,
    required this.x,
    required this.y,
    this.passageOrder,
    this.role = BuoyRole.regular,
  });
  final int id; // simple incremental id
  final double x;
  final double y;
  final int? passageOrder; // ordre de passage (1,2,3...) éventuellement
  final BuoyRole role; // rôle spécifique (parcours, comité, viseur)

  Buoy copyWith({
    int? id,
    double? x,
    double? y,
    int? passageOrder = _noIntSentinel,
    BuoyRole? role,
  }) => Buoy(
        id: id ?? this.id,
        x: x ?? this.x,
        y: y ?? this.y,
        passageOrder: passageOrder == _noIntSentinel ? this.passageOrder : passageOrder,
        role: role ?? this.role,
      );

  static const int _noIntSentinel = -9999999; // interne pour différencier null explicite
}

enum LineType { start, finish }

class LineSegment {
  LineSegment({required this.p1x, required this.p1y, required this.p2x, required this.p2y, required this.type});
  final double p1x;
  final double p1y;
  final double p2x;
  final double p2y;
  final LineType type;
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