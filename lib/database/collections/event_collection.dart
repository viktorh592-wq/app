/// Activity / event collection (FR-001). Every activity belongs to exactly
/// one organizer (BR-001).
import 'package:pokatuha/database/base_entity.dart';
import 'package:pokatuha/database/collections/embedded/geo_point.dart';

class EventCollection extends BaseEntity {
  String title = '';
  String description = '';

  /// Group this activity belongs to (V2 Group-first model,
  /// ARCHITECTURE_V2.md §2). null — legacy V1 activity created before
  /// groups existed; kept readable for soft migration (FIX_PLAN S1-T4).
  String? groupId;

  /// Activity type id (ActivityTypeCollection.id) — supports custom types (FR-002).
  String activityTypeId = '';

  /// Event status / stage (Glossary.md — Stage).
  String status = 'preparation';

  /// Visibility (Privacy rules).
  String visibility = 'private';

  /// Activity accent color (ARGB int) — V2 GROUPS_AND_ACTIVITIES.md §10, §11.
  /// Propagates to cards, chat bubbles, polls, route polyline and map rings.
  int? accentColor;

  /// Whether the activity is pinned in its group (V2 §9 — activity menu).
  bool pinnedInGroup = false;

  /// Default accent color ARGB (violet) — matches ActivityColors.swatches.first.
  static const int defaultAccentColorArgb = 0xFF9B8AFB;

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
      'groupId': groupId,
      'accentColor': accentColor,
      'pinnedInGroup': pinnedInGroup,
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
    groupId = m['groupId'] as String?;
    accentColor = (m['accentColor'] as num?)?.toInt();
    pinnedInGroup = m['pinnedInGroup'] as bool? ?? false;
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
