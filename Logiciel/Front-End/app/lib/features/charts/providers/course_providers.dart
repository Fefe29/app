import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/course.dart';

class CourseNotifier extends Notifier<CourseState> {
  int _nextId = 1;
  @override
  CourseState build() => CourseState.initial();

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

  void clear() {
    _nextId = 1;
    state = CourseState.initial();
  }
}

final courseProvider = NotifierProvider<CourseNotifier, CourseState>(CourseNotifier.new);