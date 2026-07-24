/// Participant collection — belongs to an Event and a User
/// (Entity_Relationships.md).
import 'package:pokatuha/database/base_entity.dart';

class ParticipantCollection extends BaseEntity {
  String eventId = '';
  String userId = '';

  /// ParticipantStatus enum stored as string.
  String status = 'invited';

  /// ParticipantRole enum stored as string (BR-004).
  String role = 'member';

  /// Last known live GPS (Live Mode — FR-005).
  double? lastLat;
  double? lastLng;
  double? lastSpeed;
  double? lastHeading;
  int? lastBattery;
  int? lastSeenAt;

  /// Whether the participant is currently sharing GPS (BR-005).
  bool gpsSharing = false;

  /// Last arrival stage reached (FR-006).
  String? arrivalStage;

  int? joinedAt;
  int? leftAt;

  @override
  Map<String, dynamic> toMap() => baseToMap()
    ..addAll({
      'eventId': eventId,
      'userId': userId,
      'status': status,
      'role': role,
      'lastLat': lastLat,
      'lastLng': lastLng,
      'lastSpeed': lastSpeed,
      'lastHeading': lastHeading,
      'lastBattery': lastBattery,
      'lastSeenAt': lastSeenAt,
      'gpsSharing': gpsSharing,
      'arrivalStage': arrivalStage,
      'joinedAt': joinedAt,
      'leftAt': leftAt,
    });

  @override
  void applyMap(Map<String, dynamic> m) {
    baseFromMap(m);
    eventId = m['eventId'] as String? ?? '';
    userId = m['userId'] as String? ?? '';
    status = m['status'] as String? ?? 'invited';
    role = m['role'] as String? ?? 'member';
    lastLat = (m['lastLat'] as num?)?.toDouble();
    lastLng = (m['lastLng'] as num?)?.toDouble();
    lastSpeed = (m['lastSpeed'] as num?)?.toDouble();
    lastHeading = (m['lastHeading'] as num?)?.toDouble();
    lastBattery = (m['lastBattery'] as num?)?.toInt();
    lastSeenAt = (m['lastSeenAt'] as num?)?.toInt();
    gpsSharing = m['gpsSharing'] as bool? ?? false;
    arrivalStage = m['arrivalStage'] as String?;
    joinedAt = (m['joinedAt'] as num?)?.toInt();
    leftAt = (m['leftAt'] as num?)?.toInt();
  }

  static ParticipantCollection fromMap(Map<String, dynamic> m) =>
      ParticipantCollection()..applyMap(m);
}
