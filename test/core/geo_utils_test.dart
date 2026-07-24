import 'package:flutter_test/flutter_test.dart';
import 'package:pokatuha/core/utils/geo_utils.dart';

void main() {
  group('GeoUtils', () {
    test('distance between identical points is zero', () {
      expect(
        GeoUtils.distanceMeters(lat1: 50, lng1: 30, lat2: 50, lng2: 30),
        closeTo(0, 0.01),
      );
    });

    test('distance Kyiv -> Lviv is roughly 460km', () {
      final d = GeoUtils.distanceMeters(
        lat1: 50.4501,
        lng1: 30.5234,
        lat2: 49.8397,
        lng2: 24.0297,
      );
      expect(d, closeTo(460000, 20000));
    });

    test('bearing east is ~90 degrees', () {
      final b = GeoUtils.bearingDegrees(
        lat1: 0,
        lng1: 0,
        lat2: 0,
        lng2: 1,
      );
      expect(b, closeTo(90, 1));
    });

    test('eta minutes is zero when not moving', () {
      expect(GeoUtils.etaMinutes(1000, 0), 0);
    });

    test('eta minutes for 1km at 1 m/s is ~17 min', () {
      expect(GeoUtils.etaMinutes(1000, 1), 17);
    });

    test('arrival stages by distance', () {
      expect(GeoUtils.arrivalStage(600), isNull);
      expect(GeoUtils.arrivalStage(400), ArrivalStage.near);
      expect(GeoUtils.arrivalStage(150), ArrivalStage.close);
      expect(GeoUtils.arrivalStage(10), ArrivalStage.arrived);
    });
  });
}
