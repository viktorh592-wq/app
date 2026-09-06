/// Geocoding service — address search + reverse geocoding via the
/// OpenStreetMap Nominatim API (V3.0.4 — bug 3, meeting point picker).
///
/// Usage policy compliance (operations.osmfoundation.org/policies/nominatim):
///   * a descriptive User-Agent is sent with every request;
///   * the UI debounces queries (≥ 600 ms) — never more than ~1 req/s;
///   * failures degrade gracefully (empty results / null address), the map
///     picker stays fully usable offline (tap-to-pick without an address).
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// One search result (a place suggestion).
class GeoSuggestion {
  GeoSuggestion({
    required this.displayName,
    required this.lat,
    required this.lng,
  });

  /// Full display name as returned by Nominatim
  /// («улица Ленина, Москва, Россия»).
  final String displayName;
  final double lat;
  final double lng;
}

class GeocodingService {
  GeocodingService({
    http.Client? client,
    this.acceptLanguage = 'ru',
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String acceptLanguage;

  static const String _baseUrl = 'https://nominatim.openstreetmap.org';
  static const String _userAgent = 'Pokatuha/3.0.4 (com.pokatuha.app)';

  Map<String, String> get _headers => {
        'User-Agent': _userAgent,
        'Accept': 'application/json',
      };

  /// Forward search: a free-text query → up to [limit] suggestions.
  /// Returns `null` on network/server errors (the UI shows a connection
  /// hint) and an empty list when nothing matched.
  Future<List<GeoSuggestion>?> search(
    String query, {
    int limit = 5,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    try {
      final uri = Uri.parse('$_baseUrl/search').replace(queryParameters: {
        'q': q,
        'format': 'jsonv2',
        'limit': '$limit',
        'addressdetails': '0',
        'accept-language': acceptLanguage,
      });
      final response = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      return _parseSuggestions(utf8.decode(response.bodyBytes));
    } catch (_) {
      return null;
    }
  }

  /// Reverse geocoding: coordinates → a human-readable address, or null
  /// when the lookup fails / finds nothing (the caller falls back to the
  /// raw coordinate label).
  Future<String?> reverse({required double lat, required double lng}) async {
    try {
      final uri =
          Uri.parse('$_baseUrl/reverse').replace(queryParameters: {
        'lat': '$lat',
        'lon': '$lng',
        'format': 'jsonv2',
        'zoom': '18',
        'accept-language': acceptLanguage,
      });
      final response = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      // Decode explicitly as UTF-8: response.body re-encodes using the
      // content-type charset and Nominatim payloads are full of Cyrillic.
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) return null;
      final address = decoded['display_name'];
      return address is String && address.isNotEmpty ? address : null;
    } catch (_) {
      return null;
    }
  }

  /// Visible for testing — parses the /search JSON payload.
  static List<GeoSuggestion> parseSuggestions(String body) =>
      _parseSuggestions(body);

  static List<GeoSuggestion> _parseSuggestions(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! List) return [];
      final result = <GeoSuggestion>[];
      for (final raw in decoded) {
        if (raw is! Map<String, dynamic>) continue;
        final name = raw['display_name'];
        final lat = double.tryParse('${raw['lat']}');
        final lng = double.tryParse('${raw['lon']}');
        if (name is! String || name.isEmpty) continue;
        if (lat == null || lng == null) continue;
        result.add(GeoSuggestion(displayName: name, lat: lat, lng: lng));
      }
      return result;
    } catch (_) {
      return [];
    }
  }
}
