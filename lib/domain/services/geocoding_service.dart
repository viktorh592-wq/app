/// Geocoding service — wraps OpenStreetMap Nominatim API.
///
/// Architecture rationale (ADR-007 — Geocoding via OpenStreetMap Nominatim):
///   • Free, no API key required
///   • Uses OSM data — consistent with the map provider rule (Rule 7 —
///     OpenStreetMap/MapLibre default)
///   • Local-First compliant — the service is stateless and makes HTTP calls
///     only on demand (no cloud storage)
///
/// Usage policy: Nominatim's public endpoint requires a valid User-Agent
/// and is rate-limited to 1 request/sec. For production deployments users
/// can run their own Nominatim instance and override [endpoint].
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

/// A single geocoding result.
class GeocodingResult {
  GeocodingResult({
    required this.lat,
    required this.lng,
    required this.displayName,
    this.shortName,
    this.country,
    this.city,
    this.road,
    this.houseNumber,
  });

  /// Latitude in decimal degrees.
  final double lat;

  /// Longitude in decimal degrees.
  final double lng;

  /// Full human-readable address (Nominatim `display_name`).
  final String displayName;

  /// Optional short label (street + house number, or city).
  final String? shortName;

  /// Optional structured fields (present when Nominatim returned `address`).
  final String? country;
  final String? city;
  final String? road;
  final String? houseNumber;

  /// A one-line label suitable for a TextField: prefer shortName, fall back
  /// to the first comma-separated component of displayName, then to the
  /// full displayName.
  String get label {
    if (shortName != null && shortName!.isNotEmpty) return shortName!;
    if (displayName.isEmpty) return '';
    final first = displayName.split(',').first.trim();
    return first.isEmpty ? displayName : first;
  }
}

class GeocodingService {
  GeocodingService({http.Client? client, String? endpoint})
      : _client = client ?? http.Client(),
        _endpoint = endpoint ?? 'https://nominatim.openstreetmap.org';

  final http.Client _client;
  final String _endpoint;

  /// Forward geocoding: search by free-text query.
  ///
  /// Returns up to [limit] results, ordered by Nominatim relevance.
  /// Uses the public Nominatim endpoint by default — callers should not
  /// exceed 1 request per second to respect the usage policy.
  Future<List<GeocodingResult>> search(
    String query, {
    int limit = 5,
    String acceptLanguage = 'ru',
  }) async {
    final q = query.trim();
    if (q.isEmpty) return const <GeocodingResult>[];
    final uri = Uri.parse('$_endpoint/search').replace(queryParameters: {
      'q': q,
      'format': 'jsonv2',
      'addressdetails': '1',
      'limit': limit.toString(),
      'accept-language': acceptLanguage,
    });
    final resp = await _client.get(uri, headers: {
      'User-Agent': 'Pokatuha/3.0 (https://pokatuha.app)',
    });
    if (resp.statusCode != 200) {
      throw GeocodingException(
        'Nominatim search failed: HTTP ${resp.statusCode}',
      );
    }
    if (resp.body.isEmpty) return const <GeocodingResult>[];
    final decoded = jsonDecode(resp.body);
    if (decoded is! List) return const <GeocodingResult>[];
    final out = <GeocodingResult>[];
    for (final raw in decoded) {
      if (raw is! Map<String, dynamic>) continue;
      final parsed = _resultFromMap(raw);
      if (parsed != null) out.add(parsed);
    }
    return out;
  }

  /// Reverse geocoding: address by coordinate.
  Future<GeocodingResult?> reverse(
    double lat,
    double lng, {
    String acceptLanguage = 'ru',
  }) async {
    final uri = Uri.parse('$_endpoint/reverse').replace(queryParameters: {
      'lat': lat.toStringAsFixed(6),
      'lon': lng.toStringAsFixed(6),
      'format': 'jsonv2',
      'addressdetails': '1',
      'accept-language': acceptLanguage,
    });
    final resp = await _client.get(uri, headers: {
      'User-Agent': 'Pokatuha/3.0 (https://pokatuha.app)',
    });
    if (resp.statusCode != 200) {
      throw GeocodingException(
        'Nominatim reverse failed: HTTP ${resp.statusCode}',
      );
    }
    if (resp.body.isEmpty) return null;
    final decoded = jsonDecode(resp.body);
    if (decoded is! Map<String, dynamic>) return null;
    // Nominatim returns an `error` field on miss (e.g. "Unable to geocode").
    if (decoded['error'] != null) return null;
    return _resultFromMap(decoded);
  }

  GeocodingResult? _resultFromMap(Map<String, dynamic> m) {
    final latRaw = m['lat'];
    final lonRaw = m['lon'];
    if (latRaw == null || lonRaw == null) return null;
    final lat = double.tryParse(latRaw.toString());
    final lng = double.tryParse(lonRaw.toString());
    if (lat == null || lng == null) return null;
    final display = (m['display_name'] as String?)?.trim() ?? '';
    final addr = m['address'] is Map<String, dynamic>
        ? m['address'] as Map<String, dynamic>
        : <String, dynamic>{};
    final road = (addr['road'] as String?)?.trim();
    final house = (addr['house_number'] as String?)?.trim();
    final city = (addr['city'] as String?)?.trim() ??
        (addr['town'] as String?)?.trim() ??
        (addr['village'] as String?)?.trim() ??
        (addr['hamlet'] as String?)?.trim();
    final country = (addr['country'] as String?)?.trim();
    final short = <String>[
      if (road != null && road.isNotEmpty) road,
      if (house != null && house.isNotEmpty) house,
    ].join(', ');
    return GeocodingResult(
      lat: lat,
      lng: lng,
      displayName: display,
      shortName: short.isEmpty ? null : short,
      country: country,
      city: city,
      road: road,
      houseNumber: house,
    );
  }

  void dispose() {
    _client.close();
  }
}

/// Raised when Nominatim returns an error or unparsable response.
class GeocodingException implements Exception {
  GeocodingException(this.message);
  final String message;
  @override
  String toString() => 'GeocodingException: $message';
}
