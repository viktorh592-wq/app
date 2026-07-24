/// Statistics collection (Statistics module — distance, elevation, avg speed,
/// ride duration, participation).
import 'package:pokatuha/database/base_entity.dart';

class StatisticsCollection extends BaseEntity {
  String eventId = '';
  String userId = '';

  double distanceMeters = 0;
  double elevationGainMeters = 0;
  double averageSpeed = 0;
  double maxSpeed = 0;
  int durationSeconds = 0;
  int participationCount = 0;

  @override
  Map<String, dynamic> toMap() => baseToMap()
    ..addAll({
      'eventId': eventId,
      'userId': userId,
      'distanceMeters': distanceMeters,
      'elevationGainMeters': elevationGainMeters,
      'averageSpeed': averageSpeed,
      'maxSpeed': maxSpeed,
      'durationSeconds': durationSeconds,
      'participationCount': participationCount,
    });

  @override
  void applyMap(Map<String, dynamic> m) {
    baseFromMap(m);
    eventId = m['eventId'] as String? ?? '';
    userId = m['userId'] as String? ?? '';
    distanceMeters = (m['distanceMeters'] as num?)?.toDouble() ?? 0;
    elevationGainMeters = (m['elevationGainMeters'] as num?)?.toDouble() ?? 0;
    averageSpeed = (m['averageSpeed'] as num?)?.toDouble() ?? 0;
    maxSpeed = (m['maxSpeed'] as num?)?.toDouble() ?? 0;
    durationSeconds = (m['durationSeconds'] as num?)?.toInt() ?? 0;
    participationCount = (m['participationCount'] as num?)?.toInt() ?? 0;
  }

  static StatisticsCollection fromMap(Map<String, dynamic> m) =>
      StatisticsCollection()..applyMap(m);
}
