/// Statistics service — computes ride statistics from recorded track points
/// (Statistics module — distance, elevation, avg speed, duration).
import 'package:pokatuha/core/utils/geo_utils.dart';
import 'package:pokatuha/database/collections/embedded/geo_point.dart';
import 'package:pokatuha/database/collections/statistics_collection.dart';
import 'package:pokatuha/database/collections/track_point_collection.dart';
import 'package:pokatuha/domain/repositories/statistics_repository.dart';

class StatisticsService {
  StatisticsService(this._repository);
  final StatisticsRepository _repository;

  /// Aggregate statistics over a list of recorded track points.
  ({
    double distance,
    double elevation,
    double avgSpeed,
    double maxSpeed,
    int durationSeconds
  }) aggregate(List<TrackPointCollection> points) {
    if (points.isEmpty) {
      return (
        distance: 0,
        elevation: 0,
        avgSpeed: 0,
        maxSpeed: 0,
        durationSeconds: 0,
      );
    }
    double distance = 0;
    double elevation = 0;
    double maxSpeed = 0;
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      if (p.speed > maxSpeed) maxSpeed = p.speed;
      if (i > 0) {
        final prev = points[i - 1];
        distance += GeoUtils.distanceMeters(
          lat1: prev.lat,
          lng1: prev.lng,
          lat2: p.lat,
          lng2: p.lng,
        );
        if (p.elevation > prev.elevation) {
          elevation += p.elevation - prev.elevation;
        }
      }
    }
    final durationSeconds =
        ((points.last.timestamp - points.first.timestamp) / 1000).round();
    final avgSpeed = durationSeconds > 0 ? distance / durationSeconds : 0.0;
    return (
      distance: distance,
      elevation: elevation,
      avgSpeed: avgSpeed,
      maxSpeed: maxSpeed,
      durationSeconds: durationSeconds,
    );
  }

  /// Persist statistics for a user in an event.
  Future<StatisticsCollection> saveForUser({
    required String eventId,
    required String userId,
    required List<TrackPointCollection> points,
  }) async {
    final agg = aggregate(points);
    final existing = await _repository.byEventAndUser(eventId, userId);
    final stats = existing ?? StatisticsCollection();
    stats
      ..eventId = eventId
      ..userId = userId
      ..distanceMeters = agg.distance
      ..elevationGainMeters = agg.elevation
      ..averageSpeed = agg.avgSpeed
      ..maxSpeed = agg.maxSpeed
      ..durationSeconds = agg.durationSeconds
      ..participationCount = 1;
    return _repository.save(stats);
  }

  /// Aggregate planned-route statistics from waypoints (for preview).
  ({double distance, double elevation}) routePreview(List<GeoPoint> points) {
    double distance = 0;
    double elevation = 0;
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      distance += GeoUtils.distanceMeters(
        lat1: a.lat,
        lng1: a.lng,
        lat2: b.lat,
        lng2: b.lng,
      );
      if (b.elevation > a.elevation) {
        elevation += b.elevation - a.elevation;
      }
    }
    return (distance: distance, elevation: elevation);
  }
}
