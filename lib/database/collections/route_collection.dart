/// Route collection (FR-008). Route belongs to an event and contains
/// waypoints + track points (Entity_Relationships.md).
///
/// V3 Sprint 5 (FIX_PLAN S5-T5) — added `durationSeconds` (V2 ROUTES_IMPORT.md
/// §3 — route card in chat shows distance / elevation / duration).
import 'package:pokatuha/database/base_entity.dart';
import 'package:pokatuha/database/collections/embedded/geo_point.dart';

class RouteCollection extends BaseEntity {
  String eventId = '';
  String name = '';
  String description = '';

  /// Planned waypoints (must contain at least one point — Data_Validation.md).
  List<GeoPoint> waypoints = [];

  /// Total distance in meters (computed).
  double distanceMeters = 0;

  /// Total elevation gain in meters (computed).
  double elevationGainMeters = 0;

  /// Total duration in seconds (V2 ROUTES_IMPORT.md §3 — computed from the
  /// first and last waypoint timestamps when both are non-zero, otherwise 0).
  int durationSeconds = 0;

  /// Original GPX file path (imported routes — UUID_Policy.md).
  String? gpxFilePath;

  String? originalGpxId;

  /// Whether this is a recorded track vs a planned route.
  bool isRecorded = false;

  @override
  Map<String, dynamic> toMap() => baseToMap()
    ..addAll({
      'eventId': eventId,
      'name': name,
      'description': description,
      'waypoints': waypoints.map((w) => w.toMap()).toList(),
      'distanceMeters': distanceMeters,
      'elevationGainMeters': elevationGainMeters,
      'durationSeconds': durationSeconds,
      'gpxFilePath': gpxFilePath,
      'originalGpxId': originalGpxId,
      'isRecorded': isRecorded,
    });

  @override
  void applyMap(Map<String, dynamic> m) {
    baseFromMap(m);
    eventId = m['eventId'] as String? ?? '';
    name = m['name'] as String? ?? '';
    description = m['description'] as String? ?? '';
    final wps = m['waypoints'];
    waypoints = wps is List
        ? wps
            .map((w) => GeoPoint.fromMap(Map<String, dynamic>.from(w as Map)))
            .toList()
        : [];
    distanceMeters = (m['distanceMeters'] as num?)?.toDouble() ?? 0;
    elevationGainMeters = (m['elevationGainMeters'] as num?)?.toDouble() ?? 0;
    durationSeconds = (m['durationSeconds'] as num?)?.toInt() ?? 0;
    gpxFilePath = m['gpxFilePath'] as String?;
    originalGpxId = m['originalGpxId'] as String?;
    isRecorded = m['isRecorded'] as bool? ?? false;
  }

  static RouteCollection fromMap(Map<String, dynamic> m) =>
      RouteCollection()..applyMap(m);
}
