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

  // V2 §1 — KML support (FIX_PLAN S5-T6).
  test('parseKml parses a simple LineString with coordinates', () {
    const kml = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <Placemark>
      <name>Test KML</name>
      <LineString>
        <coordinates>30.5234,50.4501,120 30.5334,50.4601,130 30.5434,50.4701,125</coordinates>
      </LineString>
    </Placemark>
  </Document>
</kml>''';
    final parsed = gpx.parseKml(kml);
    expect(parsed.length, 3);
    // KML uses lng,lat order (V2 §1 — see parseKml).
    expect(parsed.first.lat, closeTo(50.4501, 0.0001));
    expect(parsed.first.lng, closeTo(30.5234, 0.0001));
    expect(parsed.first.elevation, 120);
  });

  test('parseKml collects coordinates from multiple Placemarks', () {
    const kml = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <Placemark>
      <LineString><coordinates>30.5234,50.4501,0</coordinates></LineString>
    </Placemark>
    <Placemark>
      <LineString><coordinates>30.5334,50.4601,0 30.5434,50.4701,0</coordinates></LineString>
    </Placemark>
  </Document>
</kml>''';
    final parsed = gpx.parseKml(kml);
    expect(parsed.length, 3);
  });

  test('parseKml attaches gx:Track timestamps when count matches', () {
    const kml = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2" xmlns:gx="http://www.google.com/kml/ext/2.2">
  <Placemark>
    <gx:Track>
      <when>2024-01-01T10:00:00Z</when>
      <when>2024-01-01T10:05:00Z</when>
      <coord>30.5234 50.4501 120</coord>
      <coord>30.5334 50.4601 130</coord>
    </gx:Track>
  </Placemark>
</kml>''';
    final parsed = gpx.parseKml(kml);
    expect(parsed.length, 2);
    expect(parsed.first.timestamp, greaterThan(0));
    expect(parsed.last.timestamp, greaterThan(0));
    // Duration = 5 minutes = 300 seconds.
    expect((parsed.last.timestamp - parsed.first.timestamp) ~/ 1000, 300);
  });

  test('parseKml rejects empty coordinates', () {
    const empty = '<?xml version="1.0"?><kml xmlns="http://www.opengis.net/kml/2.2"><Document></Document></kml>';
    expect(() => gpx.parseKml(empty), throwsA(isA<ValidationError>()));
  });

  test('parseForExtension dispatches by extension', () {
    final built = gpx.build(
      name: 'Test',
      points: [
        GeoPoint(lat: 50.4501, lng: 30.5234, elevation: 100, timestamp: 0),
        GeoPoint(lat: 50.4601, lng: 30.5334, elevation: 110, timestamp: 0),
      ],
    );
    // GPX via dispatcher.
    expect(gpx.parseForExtension(built, 'gpx').length, 2);
    // Unsupported extension throws ValidationError.
    expect(() => gpx.parseForExtension(built, 'txt'),
        throwsA(isA<ValidationError>()));
    // FIT throws with a clear message (proprietary binary, out of scope).
    expect(() => gpx.parseForExtension(built, 'fit'),
        throwsA(isA<ValidationError>()));
  });
}
