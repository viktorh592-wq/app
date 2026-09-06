/// Tests for the Nominatim geocoding service (V3.0.4 — bug 3).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:pokatuha/domain/services/geocoding_service.dart';

/// Builds an http.Response carrying UTF-8 JSON (Cyrillic-safe).
http.Response _utf8Json(Object body) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  group('search', () {
    test('parses Nominatim suggestions', () async {
      http.Request? captured;
      final client = MockClient((request) async {
        captured = request;
        // UTF-8 bytes + charset header: the default Response() constructor
        // encodes the body as latin-1 and throws on Cyrillic.
        return _utf8Json([
          {
            'display_name': 'Москва, Россия',
            'lat': '55.7558',
            'lon': '37.6173',
          },
          {
            'display_name': 'Санкт-Петербург, Россия',
            'lat': '59.9386',
            'lon': '30.3141',
          },
        ]);
      });
      final service = GeocodingService(client: client);
      final results = await service.search('москва');
      // Request-shape assertions (outside the handler so that failures are
      // not swallowed by the service's error handling).
      final req = captured;
      expect(req, isNotNull);
      expect(req!.url.host, 'nominatim.openstreetmap.org');
      expect(req.url.path, '/search');
      final ua = req.headers.entries
          .firstWhere((e) => e.key.toLowerCase() == 'user-agent')
          .value;
      expect(ua, contains('Pokatuha'));
      expect(results, hasLength(2));
      expect(results!.first.displayName, 'Москва, Россия');
      expect(results.first.lat, 55.7558);
      expect(results.first.lng, 37.6173);
    });

    test('empty query short-circuits without a network call', () async {
      var called = false;
      final client = MockClient((request) async {
        called = true;
        return http.Response('[]', 200);
      });
      final service = GeocodingService(client: client);
      expect(await service.search('   '), isEmpty);
      expect(called, isFalse);
    });

    test('network error yields null (UI shows a connection hint)', () async {
      final client = MockClient((request) async {
        throw http.ClientException('offline');
      });
      final service = GeocodingService(client: client);
      expect(await service.search('москва'), isNull);
    });

    test('server error yields null', () async {
      final client = MockClient((request) async {
        return http.Response('{"error":"rate limited"}', 429);
      });
      final service = GeocodingService(client: client);
      expect(await service.search('москва'), isNull);
    });

    test('malformed entries are skipped, not fatal', () {
      final parsed = GeocodingService.parseSuggestions(jsonEncode([
        {'display_name': 'Ok place', 'lat': '10.5', 'lon': '20.5'},
        {'display_name': 'No coordinates'},
        {'lat': '1', 'lon': '2'},
        'garbage',
      ]));
      expect(parsed, hasLength(1));
      expect(parsed.first.displayName, 'Ok place');
    });
  });

  group('reverse', () {
    test('returns display_name for a valid response', () async {
      http.Request? captured;
      final client = MockClient((request) async {
        captured = request;
        return _utf8Json({'display_name': 'Красная площадь, Москва, Россия'});
      });
      final service = GeocodingService(client: client);
      final address = await service.reverse(lat: 55.7558, lng: 37.6173);
      expect(captured, isNotNull);
      expect(captured!.url.path, '/reverse');
      expect(captured!.url.queryParameters['lat'], '55.7558');
      expect(address, 'Красная площадь, Москва, Россия');
    });

    test('missing display_name yields null', () async {
      final client = MockClient((request) async {
        return http.Response(jsonEncode({'error': 'not found'}), 200);
      });
      final service = GeocodingService(client: client);
      expect(await service.reverse(lat: 0, lng: 0), isNull);
    });

    test('network failure yields null (offline tap-to-pick still works)',
        () async {
      final client = MockClient((request) async {
        throw http.ClientException('offline');
      });
      final service = GeocodingService(client: client);
      expect(await service.reverse(lat: 10, lng: 20), isNull);
    });
  });
}
