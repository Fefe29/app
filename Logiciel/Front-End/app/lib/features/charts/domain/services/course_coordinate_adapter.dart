/// Migration adapter for converting between legacy coordinate system and geographic coordinates.
/// This file helps maintain compatibility during the transition to geographic coordinates.
import '../models/course.dart';
import '../models/boat.dart';
import '../models/geographic_position.dart';
import '../../providers/coordinate_system_provider.dart';
import '../../providers/course_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Adapter for converting Course objects between coordinate systems
class CourseCoordinateAdapter {
  static final CoordinateConverter _defaultConverter = CoordinateConverter(
    origin: const GeographicPosition(latitude: 43.5, longitude: 7.0), // Mediterranean default
  );

  /// Convert legacy CourseState with x/y coordinates to geographic coordinates
  static CourseState legacyToGeographic(
    CourseState legacyCourse,
    CoordinateConverter converter,
  ) {
    return CourseState(
      buoys: legacyCourse.buoys.map((buoy) {
        final localPos = LocalPosition(x: buoy.x, y: buoy.y);
        final geoPos = converter.localToGeographic(localPos);
        return Buoy(
          id: buoy.id,
          position: geoPos,
          passageOrder: buoy.passageOrder,
          role: buoy.role,
        );
      }).toList(),
      startLine: legacyCourse.startLine != null 
        ? LineSegment(
            point1: converter.localToGeographic(LocalPosition(x: legacyCourse.startLine!.p1x, y: legacyCourse.startLine!.p1y)),
            point2: converter.localToGeographic(LocalPosition(x: legacyCourse.startLine!.p2x, y: legacyCourse.startLine!.p2y)),
            type: legacyCourse.startLine!.type,
          )
        : null,
      finishLine: legacyCourse.finishLine != null
        ? LineSegment(
            point1: converter.localToGeographic(LocalPosition(x: legacyCourse.finishLine!.p1x, y: legacyCourse.finishLine!.p1y)),
            point2: converter.localToGeographic(LocalPosition(x: legacyCourse.finishLine!.p2x, y: legacyCourse.finishLine!.p2y)),
            type: legacyCourse.finishLine!.type,
          )
        : null,
    );
  }

  /// Convert geographic CourseState to legacy format for backward compatibility
  static CourseState geographicToLegacy(
    CourseState geoCourse,
    CoordinateConverter converter,
  ) {
    return CourseState(
      buoys: geoCourse.buoys.map((buoy) {
        final localPos = converter.geographicToLocal(buoy.position);
        return Buoy.legacy(
          id: buoy.id,
          x: localPos.x,
          y: localPos.y,
          passageOrder: buoy.passageOrder,
          role: buoy.role,
        );
      }).toList(),
      startLine: geoCourse.startLine != null
        ? (() {
            final p1 = converter.geographicToLocal(geoCourse.startLine!.point1);
            final p2 = converter.geographicToLocal(geoCourse.startLine!.point2);
            return LineSegment.legacy(
              p1x: p1.x,
              p1y: p1.y,
              p2x: p2.x,
              p2y: p2.y,
              type: geoCourse.startLine!.type,
            );
          })()
        : null,
      finishLine: geoCourse.finishLine != null
        ? (() {
            final p1 = converter.geographicToLocal(geoCourse.finishLine!.point1);
            final p2 = converter.geographicToLocal(geoCourse.finishLine!.point2);
            return LineSegment.legacy(
              p1x: p1.x,
              p1y: p1.y,
              p2x: p2.x,
              p2y: p2.y,
              type: geoCourse.finishLine!.type,
            );
          })()
        : null,
    );
  }

  /// Create a test course in geographic coordinates
  static CourseState createTestCourseGeographic(GeographicPosition origin) {
    final converter = CoordinateConverter(origin: origin);
    
    // Create test points in local meters, then convert to geographic
    final testPoints = [
      LocalPosition(x: 0, y: 50),     // Bouée 1
      LocalPosition(x: 20, y: 0),     // Viseur
      LocalPosition(x: 30, y: 0),     // Comité
      LocalPosition(x: -20, y: 50),   // Bouée 2
      LocalPosition(x: -5, y: 10),    // Bouée 3
    ];

    final geoPoints = testPoints.map(converter.localToGeographic).toList();

    return CourseState(
      buoys: [
        Buoy(id: 1, position: geoPoints[0], passageOrder: 1, role: BuoyRole.regular),
        Buoy(id: 2, position: geoPoints[1], role: BuoyRole.target),
        Buoy(id: 3, position: geoPoints[2], role: BuoyRole.committee),
        Buoy(id: 4, position: geoPoints[3], passageOrder: 2, role: BuoyRole.regular),
        Buoy(id: 5, position: geoPoints[4], passageOrder: 3, role: BuoyRole.regular),
      ],
      startLine: LineSegment(
        point1: geoPoints[1], // Viseur
        point2: geoPoints[2], // Comité
        type: LineType.start,
      ),
      finishLine: LineSegment(
        point1: converter.localToGeographic(LocalPosition(x: -25, y: -5)),
        point2: converter.localToGeographic(LocalPosition(x: -15, y: -5)),
        type: LineType.finish,
      ),
    );
  }
}

/// Extension to add coordinate conversion capabilities to CourseState
extension CourseStateCoordinateExtension on CourseState {
  /// Convert this course state to geographic coordinates
  CourseState toGeographic(CoordinateConverter converter) {
    return CourseCoordinateAdapter.geographicToLegacy(this, converter);
  }

  /// Convert this course state to legacy x/y coordinates
  CourseState toLegacy(CoordinateConverter converter) {
    return CourseCoordinateAdapter.geographicToLegacy(this, converter);
  }

  /// Get all geographic positions in this course
  List<GeographicPosition> get allGeographicPositions {
    final positions = <GeographicPosition>[];
    
    // Add buoy positions
    for (final buoy in buoys) {
      positions.add(buoy.position);
    }
    
    // Add line positions
    if (startLine != null) {
      positions.addAll([startLine!.point1, startLine!.point2]);
    }
    if (finishLine != null) {
      positions.addAll([finishLine!.point1, finishLine!.point2]);
    }
    
    return positions;
  }
}

/// Provider that automatically converts course data for display
final courseDisplayProvider = Provider<CourseState>((ref) {
  final courseState = ref.watch(courseProvider);
  final coordinateService = ref.watch(coordinateSystemProvider);
  
  // For now, we'll assume the course is in legacy format and needs conversion
  // In the future, this logic will be reversed when the course is stored in geographic format
  if (courseState.buoys.isNotEmpty && courseState.buoys.first.tempLocalPos != null) {
    // Course is in legacy format, convert to geographic for internal use
    final converter = CoordinateConverter(origin: coordinateService.config.origin);
    return CourseCoordinateAdapter.legacyToGeographic(courseState, converter);
  }
  
  return courseState;
});