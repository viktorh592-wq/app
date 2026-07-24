/// Geographic helpers: distance, bearing, ETA and arrival detection.
/// Used by the GPS module (FR-005, FR-006) and arrival notifications.
import 'dart:math' as math;

class GeoUtils {
  GeoUtils._();

  static const double _earthRadiusMeters = 6371000.0;

  /// Haversine distance in meters between two coordinates.
  static double distanceMeters({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    final phi1 = _toRad(lat1);
    final phi2 = _toRad(lat2);
    final dPhi = _toRad(lat2 - lat1);
    final dLambda = _toRad(lng2 - lng1);
    final a = math.sin(dPhi / 2) * math.sin(dPhi / 2) +
        math.cos(phi1) *
            math.cos(phi2) *
            math.sin(dLambda / 2) *
            math.sin(dLambda / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return _earthRadiusMeters * c;
  }

  /// Initial bearing in degrees [0..360) from point 1 to point 2.
  static double bearingDegrees({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    final phi1 = _toRad(lat1);
    final phi2 = _toRad(lat2);
    final dLambda = _toRad(lng2 - lng1);
    final y = math.sin(dLambda) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(dLambda);
    final theta = math.atan2(y, x);
    return (_toDeg(theta) + 360.0) % 360.0;
  }

  /// Estimated time of arrival in minutes given distance (m) and speed (m/s).
  static int etaMinutes(double distanceMeters, double speedMetersPerSecond) {
    if (speedMetersPerSecond <= 0) return 0;
    final seconds = distanceMeters / speedMetersPerSecond;
    return (seconds / 60).ceil();
  }

  /// Arrival stage based on distance to the meeting point (FR-006).
  /// Returns null when still far away.
  static ArrivalStage? arrivalStage(
    double distanceMeters, {
    double near = 500.0,
    double close = 200.0,
    double arrived = 50.0,
  }) {
    if (distanceMeters <= arrived) return ArrivalStage.arrived;
    if (distanceMeters <= close) return ArrivalStage.close;
    if (distanceMeters <= near) return ArrivalStage.near;
    return null;
  }

  static double _toRad(double deg) => deg * math.pi / 180.0;
  static double _toDeg(double rad) => rad * 180.0 / math.pi;
}

/// Three configurable arrival thresholds (FR-006).
enum ArrivalStage {
  /// "Alex is 500 m away"
  near,

  /// "John is arriving"
  close,

  /// "Maria has arrived"
  arrived,
}
