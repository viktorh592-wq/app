/// Route repository (FR-008). A route belongs to an event and contains
/// waypoints + track points (Entity_Relationships.md).
import 'package:sembast/sembast.dart';

import 'package:pokatuha/core/errors/app_error.dart';
import 'package:pokatuha/core/utils/geo_utils.dart';
import 'package:pokatuha/core/utils/timestamps.dart';
import 'package:pokatuha/core/utils/uuid.dart';
import 'package:pokatuha/core/utils/validators.dart';
import 'package:pokatuha/database/collections/embedded/geo_point.dart';
import 'package:pokatuha/database/collections/route_collection.dart';
import 'package:pokatuha/database/collections/track_point_collection.dart';
import 'package:pokatuha/database/database.dart';

class RouteRepository {
  RouteRepository(this._db);
  final DatabaseService _db;

  TypedStore<RouteCollection> get _store => _db.routesStore;
  TypedStore<TrackPointCollection> get _trackPoints => _db.trackPointsStore;

  Future<List<RouteCollection>> byEvent(String eventId) async => _store.find(
        filter: Filter.equals('eventId', eventId) &
            Filter.equals('isDeleted', false),
        sortOrders: [SortOrder('createdAt')],
      );

  Future<RouteCollection?> getById(String id) async {
    final r = await _store.getById(id);
    return (r != null && !r.isDeleted) ? r : null;
  }

  /// Create a planned route from waypoints (FR-008).
  /// A route must contain at least one point (Data_Validation.md).
  Future<RouteCollection> create({
    required String eventId,
    required String name,
    required List<GeoPoint> waypoints,
    String description = '',
    String createdBy = '',
  }) async {
    final points = waypoints.map((w) => (lat: w.lat, lng: w.lng)).toList();
    if (!Validators.isValidRoutePoints(points)) {
      throw const ValidationError(
          'Route must contain at least one valid point');
    }
    final stats = _computeStats(waypoints);
    final now = Timestamps.nowUtc();
    final route = RouteCollection()
      ..id = UuidGenerator.generate()
      ..createdAt = now
      ..updatedAt = now
      ..version = 1
      ..isDeleted = false
      ..eventId = eventId
      ..name = name.trim()
      ..description = description.trim()
      ..waypoints = waypoints
      ..distanceMeters = stats.distance
      ..elevationGainMeters = stats.elevation
      ..isRecorded = false
      ..createdBy = createdBy;
    return _store.put(route);
  }

  /// Duplicate a route (FR-008 — Duplicate route).
  Future<RouteCollection> duplicate(RouteCollection route) async {
    final now = Timestamps.nowUtc();
    final copy = RouteCollection()
      ..id = UuidGenerator.generate()
      ..createdAt = now
      ..updatedAt = now
      ..version = 1
      ..isDeleted = false
      ..eventId = route.eventId
      ..name = '${route.name} (copy)'
      ..description = route.description
      ..waypoints = List<GeoPoint>.from(route.waypoints)
      ..distanceMeters = route.distanceMeters
      ..elevationGainMeters = route.elevationGainMeters
      ..isRecorded = route.isRecorded
      ..gpxFilePath = route.gpxFilePath;
    return _store.put(copy);
  }

  /// Import a GPX file into a route (FR-008 — Import GPX).
  Future<RouteCollection> importGpx({
    required String eventId,
    required String name,
    required List<GeoPoint> waypoints,
    required String gpxFilePath,
    String? originalGpxId,
  }) async {
    final route = await create(
      eventId: eventId,
      name: name,
      waypoints: waypoints,
    );
    route
      ..gpxFilePath = gpxFilePath
      ..originalGpxId = originalGpxId;
    return _store.put(route);
  }

  /// Append a recorded track point (Live Mode recording).
  Future<void> addTrackPoint({
    required String routeId,
    required String eventId,
    required double lat,
    required double lng,
    required double elevation,
    required double speed,
    required double heading,
    int? accuracy,
  }) async {
    final now = Timestamps.nowUtc();
    final tp = TrackPointCollection()
      ..id = UuidGenerator.generate()
      ..createdAt = now
      ..updatedAt = now
      ..version = 1
      ..isDeleted = false
      ..routeId = routeId
      ..eventId = eventId
      ..timestamp = now
      ..lat = lat
      ..lng = lng
      ..elevation = elevation
      ..speed = speed
      ..heading = heading
      ..accuracy = accuracy;
    await _trackPoints.put(tp);
  }

  Future<List<TrackPointCollection>> trackPoints(String routeId) async =>
      _trackPoints.find(
        filter: Filter.equals('routeId', routeId) &
            Filter.equals('isDeleted', false),
        sortOrders: [SortOrder('timestamp')],
      );

  ({double distance, double elevation}) _computeStats(List<GeoPoint> points) {
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
