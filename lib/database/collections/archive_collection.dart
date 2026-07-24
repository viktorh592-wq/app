/// Archive collection — completed activities (FR-009). References a completed
/// event and contains messages, media, statistics, timeline, votes, GPX
/// (Entity_Relationships.md). Archived rides are never soft-deleted
/// automatically (Soft_Delete.md). An archived activity cannot become active
/// again (BR-002).
import 'package:pokatuha/database/base_entity.dart';

class ArchiveCollection extends BaseEntity {
  /// One archive per event (unique).
  String eventId = '';

  String title = '';
  String activityTypeId = '';

  int rideStartedAt = 0;
  int rideFinishedAt = 0;

  /// Aggregate statistics id (StatisticsCollection.id).
  String? statisticsId;

  /// Number of participants.
  int participantCount = 0;

  /// Summary distance / duration / elevation.
  double distanceMeters = 0;
  int durationSeconds = 0;
  double elevationGainMeters = 0;
  double averageSpeed = 0;

  /// GPX archive path.
  String? gpxFilePath;

  /// Timeline events serialized (BR-010).
  String? timelineJson;

  /// Photo / video metadata ids serialized.
  String? mediaIdsJson;

  @override
  Map<String, dynamic> toMap() => baseToMap()
    ..addAll({
      'eventId': eventId,
      'title': title,
      'activityTypeId': activityTypeId,
      'rideStartedAt': rideStartedAt,
      'rideFinishedAt': rideFinishedAt,
      'statisticsId': statisticsId,
      'participantCount': participantCount,
      'distanceMeters': distanceMeters,
      'durationSeconds': durationSeconds,
      'elevationGainMeters': elevationGainMeters,
      'averageSpeed': averageSpeed,
      'gpxFilePath': gpxFilePath,
      'timelineJson': timelineJson,
      'mediaIdsJson': mediaIdsJson,
    });

  @override
  void applyMap(Map<String, dynamic> m) {
    baseFromMap(m);
    eventId = m['eventId'] as String? ?? '';
    title = m['title'] as String? ?? '';
    activityTypeId = m['activityTypeId'] as String? ?? '';
    rideStartedAt = (m['rideStartedAt'] as num?)?.toInt() ?? 0;
    rideFinishedAt = (m['rideFinishedAt'] as num?)?.toInt() ?? 0;
    statisticsId = m['statisticsId'] as String?;
    participantCount = (m['participantCount'] as num?)?.toInt() ?? 0;
    distanceMeters = (m['distanceMeters'] as num?)?.toDouble() ?? 0;
    durationSeconds = (m['durationSeconds'] as num?)?.toInt() ?? 0;
    elevationGainMeters = (m['elevationGainMeters'] as num?)?.toDouble() ?? 0;
    averageSpeed = (m['averageSpeed'] as num?)?.toDouble() ?? 0;
    gpxFilePath = m['gpxFilePath'] as String?;
    timelineJson = m['timelineJson'] as String?;
    mediaIdsJson = m['mediaIdsJson'] as String?;
  }

  static ArchiveCollection fromMap(Map<String, dynamic> m) =>
      ArchiveCollection()..applyMap(m);
}
