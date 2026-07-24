import 'package:flutter_test/flutter_test.dart';
import 'package:pokatuha/core/errors/app_error.dart';
import 'package:pokatuha/database/collections/embedded/geo_point.dart';
import 'package:pokatuha/domain/services/gpx_service.dart';

void main() {
  final gpx = GpxService();

  test('build + parse round trip preserves points', () {
    final xml = gpx.build(
      name: 'Test route',
      points: [
        GeoPoint(lat: 50.4501, lng: 30.5234, elevation: 120, timestamp: 0),
        GeoPoint(lat: 50.4601, lng: 30.5334, elevation: 130, timestamp: 0),
        GeoPoint(lat: 50.4701, lng: 30.5434, elevation: 125, timestamp: 0),
      ],
    );
    final parsed = gpx.parse(xml);
    expect(parsed.length, 3);
    expect(parsed.first.lat, closeTo(50.4501, 0.0001));
    expect(parsed.first.lng, closeTo(30.5234, 0.0001));
    expect(parsed.first.elevation, 120);
  });

  test('parse rejects invalid XML', () {
    expect(() => gpx.parse('not xml'), throwsA(isA<ValidationError>()));
  });

  test('parse rejects GPX with no points', () {
    const empty = '<?xml version="1.0"?>'
        '<gpx version="1.1" creator="x" xmlns="http://www.topografix.com/GPX/1/1"></gpx>';
    expect(() => gpx.parse(empty), throwsA(isA<ValidationError>()));
  });
}
