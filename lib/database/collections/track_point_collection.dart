/// Track point collection — recorded GPS samples during a ride (Live Mode).
/// Kept as a separate collection from route waypoints to scale to large
/// recorded tracks without loading everything at once.
import 'package:pokatuha/database/base_entity.dart';

class TrackPointCollection extends BaseEntity {
  String routeId = '';
  String eventId = '';
  int timestamp = 0;

  double lat = 0;
  double lng = 0;
  double elevation = 0;
  double speed = 0;
  double heading = 0;
  int? accuracy;

  @override
  Map<String, dynamic> toMap() => baseToMap()
    ..addAll({
      'routeId': routeId,
      'eventId': eventId,
      'timestamp': timestamp,
      'lat': lat,
      'lng': lng,
      'elevation': elevation,
      'speed': speed,
      'heading': heading,
      'accuracy': accuracy,
    });

  @override
  void applyMap(Map<String, dynamic> m) {
    baseFromMap(m);
    routeId = m['routeId'] as String? ?? '';
    eventId = m['eventId'] as String? ?? '';
    timestamp = (m['timestamp'] as num?)?.toInt() ?? 0;
    lat = (m['lat'] as num?)?.toDouble() ?? 0;
    lng = (m['lng'] as num?)?.toDouble() ?? 0;
    elevation = (m['elevation'] as num?)?.toDouble() ?? 0;
    speed = (m['speed'] as num?)?.toDouble() ?? 0;
    heading = (m['heading'] as num?)?.toDouble() ?? 0;
    accuracy = (m['accuracy'] as num?)?.toInt();
  }

  static TrackPointCollection fromMap(Map<String, dynamic> m) =>
      TrackPointCollection()..applyMap(m);
}
