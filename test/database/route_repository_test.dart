import 'package:flutter_test/flutter_test.dart';
import 'package:pokatuha/database/collections/embedded/geo_point.dart';
import 'package:pokatuha/database/collections/route_collection.dart';
import 'package:pokatuha/database/database.dart';
import 'package:pokatuha/domain/repositories/route_repository.dart';

/// V2 ROUTES_IMPORT.md §3 — RouteCollection.durationSeconds is computed
/// from the first and last waypoint timestamps when both are non-zero
/// (FIX_PLAN S5-T5).
void main() {
  late DatabaseService db;
  late RouteRepository routes;
  const eventId = 'event-1';

  setUp(() async {
    db = await DatabaseService.memory();
    routes = RouteRepository(db);
  });

  tearDown(() => db.close());

  test('create computes durationSeconds from waypoint timestamps', () async {
    final now = DateTime.utc(2024, 1, 1, 10, 0, 0).millisecondsSinceEpoch;
    final later = DateTime.utc(2024, 1, 1, 10, 5, 0).millisecondsSinceEpoch;
    final route = await routes.create(
      eventId: eventId,
      name: 'Recorded',
      waypoints: [
        GeoPoint(lat: 50.4501, lng: 30.5234, elevation: 100, timestamp: now),
        GeoPoint(lat: 50.4601, lng: 30.5334, elevation: 110, timestamp: later),
      ],
    );
    // 5 minutes = 300 seconds.
    expect(route.durationSeconds, 300);
    expect(route.distanceMeters, greaterThan(0));
  });

  test('create leaves durationSeconds=0 when timestamps are zero', () async {
    final route = await routes.create(
      eventId: eventId,
      name: 'Planned',
      waypoints: [
        GeoPoint(lat: 50.4501, lng: 30.5234, elevation: 100, timestamp: 0),
        GeoPoint(lat: 50.4601, lng: 30.5334, elevation: 110, timestamp: 0),
      ],
    );
    expect(route.durationSeconds, 0);
  });

  test('duplicate preserves durationSeconds', () async {
    final now = DateTime.utc(2024, 1, 1, 10, 0, 0).millisecondsSinceEpoch;
    final later = DateTime.utc(2024, 1, 1, 10, 30, 0).millisecondsSinceEpoch;
    final route = await routes.create(
      eventId: eventId,
      name: 'Original',
      waypoints: [
        GeoPoint(lat: 50.4501, lng: 30.5234, elevation: 100, timestamp: now),
        GeoPoint(lat: 50.4601, lng: 30.5334, elevation: 110, timestamp: later),
      ],
    );
    final dup = await routes.duplicate(route);
    expect(dup.durationSeconds, route.durationSeconds);
    expect(dup.distanceMeters, route.distanceMeters);
    expect(dup.name, contains('copy'));
  });

  test('RouteCollection round-trips durationSeconds through toMap/fromMap',
      () {
    final now = DateTime.utc(2024, 1, 1, 10, 0, 0).millisecondsSinceEpoch;
    final later = DateTime.utc(2024, 1, 1, 11, 0, 0).millisecondsSinceEpoch;
    final route = RouteCollection()
      ..id = 'r1'
      ..eventId = eventId
      ..name = 'RT'
      ..durationSeconds = 3600
      ..waypoints = [
        GeoPoint(lat: 50.4501, lng: 30.5234, elevation: 100, timestamp: now),
        GeoPoint(lat: 50.4601, lng: 30.5334, elevation: 110, timestamp: later),
      ];
    final m = route.toMap();
    expect(m['durationSeconds'], 3600);
    final restored = RouteCollection.fromMap(m);
    expect(restored.durationSeconds, 3600);
  });
}
