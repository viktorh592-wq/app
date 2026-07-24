/// Embedded geographic coordinate used by routes, waypoints and track points.
/// Plain serializable class (ADR-005 — Sembast storage).
class GeoPoint {
  GeoPoint(
      {this.lat = 0, this.lng = 0, this.elevation = 0, this.timestamp = 0});

  /// Latitude in decimal degrees (-90..90).
  double lat;

  /// Longitude in decimal degrees (-180..180).
  double lng;

  /// Elevation in meters.
  double elevation;

  /// UTC milliseconds (Timestamp_Policy.md).
  int timestamp;

  Map<String, dynamic> toMap() => {
        'lat': lat,
        'lng': lng,
        'elevation': elevation,
        'timestamp': timestamp,
      };

  static GeoPoint fromMap(Map<String, dynamic> m) => GeoPoint(
        lat: (m['lat'] as num?)?.toDouble() ?? 0,
        lng: (m['lng'] as num?)?.toDouble() ?? 0,
        elevation: (m['elevation'] as num?)?.toDouble() ?? 0,
        timestamp: (m['timestamp'] as num?)?.toInt() ?? 0,
      );
}
