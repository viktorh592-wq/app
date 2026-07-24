/// Activity / event collection (FR-001). Every activity belongs to exactly
/// one organizer (BR-001).
import 'package:pokatuha/database/base_entity.dart';
import 'package:pokatuha/database/collections/embedded/geo_point.dart';

class EventCollection extends BaseEntity {
  String title = '';
  String description = '';

  /// Activity type id (ActivityTypeCollection.id) — supports custom types (FR-002).
  String activityTypeId = '';

  /// Event status / stage (Glossary.md — Stage).
  String status = 'preparation';

  /// Visibility (Privacy rules).
  String visibility = 'private';

  /// Organizer user id (BR-001).
  String organizerId = '';

  /// Start time in UTC ms (Timestamp_Policy.md).
  int startAt = 0;

  int? rideStartedAt;
  int? rideFinishedAt;

  /// Meeting point coordinates.
  GeoPoint? meetingPoint;

  String? meetingPointLabel;

  int? maxParticipants;

  String? coverImagePath;

  /// Weather snapshot id (WeatherModule cache).
  String? weatherSnapshotId;

  /// Thresholds for arrival detection (FR-006) in meters.
  double arrivalThresholdNear = 500.0;
  double arrivalThresholdClose = 200.0;
  double arrivalThresholdArrived = 50.0;

  /// Whether GPS sharing is enabled for this ride (BR-005).
  bool gpsSharingEnabled = false;

  @override
  Map<String, dynamic> toMap() => baseToMap()
    ..addAll({
      'title': title,
      'description': description,
      'activityTypeId': activityTypeId,
      'status': status,
      'visibility': visibility,
      'organizerId': organizerId,
      'startAt': startAt,
      'rideStartedAt': rideStartedAt,
      'rideFinishedAt': rideFinishedAt,
      'meetingPoint': meetingPoint?.toMap(),
      'meetingPointLabel': meetingPointLabel,
      'maxParticipants': maxParticipants,
      'coverImagePath': coverImagePath,
      'weatherSnapshotId': weatherSnapshotId,
      'arrivalThresholdNear': arrivalThresholdNear,
      'arrivalThresholdClose': arrivalThresholdClose,
      'arrivalThresholdArrived': arrivalThresholdArrived,
      'gpsSharingEnabled': gpsSharingEnabled,
    });

  @override
  void applyMap(Map<String, dynamic> m) {
    baseFromMap(m);
    title = m['title'] as String? ?? '';
    description = m['description'] as String? ?? '';
    activityTypeId = m['activityTypeId'] as String? ?? '';
    status = m['status'] as String? ?? 'preparation';
    visibility = m['visibility'] as String? ?? 'private';
    organizerId = m['organizerId'] as String? ?? '';
    startAt = (m['startAt'] as num?)?.toInt() ?? 0;
    rideStartedAt = (m['rideStartedAt'] as num?)?.toInt();
    rideFinishedAt = (m['rideFinishedAt'] as num?)?.toInt();
    final mp = m['meetingPoint'];
    meetingPoint =
        mp is Map ? GeoPoint.fromMap(Map<String, dynamic>.from(mp)) : null;
    meetingPointLabel = m['meetingPointLabel'] as String?;
    maxParticipants = (m['maxParticipants'] as num?)?.toInt();
    coverImagePath = m['coverImagePath'] as String?;
    weatherSnapshotId = m['weatherSnapshotId'] as String?;
    arrivalThresholdNear =
        (m['arrivalThresholdNear'] as num?)?.toDouble() ?? 500.0;
    arrivalThresholdClose =
        (m['arrivalThresholdClose'] as num?)?.toDouble() ?? 200.0;
    arrivalThresholdArrived =
        (m['arrivalThresholdArrived'] as num?)?.toDouble() ?? 50.0;
    gpsSharingEnabled = m['gpsSharingEnabled'] as bool? ?? false;
  }

  static EventCollection fromMap(Map<String, dynamic> m) =>
      EventCollection()..applyMap(m);
}
