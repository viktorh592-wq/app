import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:pokatuha/domain/services/geocoding_service.dart';

// Helper — http.Response defaults to Latin1 encoding which mangles Cyrillic;
// all Nominatim payloads come back as UTF-8 so we encode explicitly.
http.Response _utf8Response(String body, int statusCode) {
  return http.Response.bytes(
    utf8.encode(body),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  group('GeocodingService', () {
    test('search returns parsed results', () async {
      final client = MockClient((request) async {
        expect(request.url.path, endsWith('/search'));
        expect(request.url.queryParameters['q'], 'Киев');
        expect(request.headers['User-Agent'], contains('Pokatuha'));
        return _utf8Response(
          jsonEncode([
            {
              'lat': '50.4501',
              'lon': '30.5234',
              'display_name': 'Kyiv, Ukraine',
              'address': {
                'city': 'Kyiv',
                'country': 'Ukraine',
              },
            },
          ]),
          200,
        );
      });
      final svc = GeocodingService(client: client, endpoint: 'https://test.local');
      final results = await svc.search('Киев');
      expect(results.length, 1);
      expect(results.first.lat, 50.4501);
      expect(results.first.lng, 30.5234);
      expect(results.first.city, 'Kyiv');
      expect(results.first.country, 'Ukraine');
      expect(results.first.label, 'Kyiv');
    });

    test('search returns empty list for empty query', () async {
      final svc = GeocodingService(client: MockClient((_) async => _utf8Response('[]', 200)));
      expect(await svc.search(''), isEmpty);
    });

    test('search throws on HTTP error', () async {
      final svc = GeocodingService(
        client: MockClient((_) async => _utf8Response('', 500)),
        endpoint: 'https://test.local',
      );
      expect(() => svc.search('test'), throwsA(isA<GeocodingException>()));
    });

    test('reverse returns parsed result', () async {
      final client = MockClient((request) async {
        expect(request.url.path, endsWith('/reverse'));
        expect(request.url.queryParameters['lat'], '50.450100');
        expect(request.url.queryParameters['lon'], '30.523400');
        return _utf8Response(
          jsonEncode({
            'lat': '50.4501',
            'lon': '30.5234',
            'display_name': 'Хрещатик, 1, Київ, Україна',
            'address': {
              'road': 'Хрещатик',
              'house_number': '1',
              'city': 'Київ',
              'country': 'Україна',
            },
          }),
          200,
        );
      });
      final svc = GeocodingService(client: client, endpoint: 'https://test.local');
      final result = await svc.reverse(50.4501, 30.5234);
      expect(result, isNotNull);
      expect(result!.shortName, 'Хрещатик, 1');
      expect(result.label, 'Хрещатик, 1');
      expect(result.displayName, 'Хрещатик, 1, Київ, Україна');
    });

    test('reverse returns null for unknown coordinates', () async {
      final client = MockClient((_) async => _utf8Response(
        jsonEncode({'error': 'Unable to geocode'}),
        200,
      ));
      final svc = GeocodingService(client: client, endpoint: 'https://test.local');
      expect(await svc.reverse(0, 0), isNull);
    });

    test('label falls back to first comma of displayName when no shortName', () async {
      final r = GeocodingResult(
        lat: 1,
        lng: 2,
        displayName: 'First Component, Second, Third',
        shortName: null,
      );
      expect(r.label, 'First Component');
    });

    test('label falls back to full displayName when nothing else is set', () {
      final r = GeocodingResult(
        lat: 1,
        lng: 2,
        displayName: 'Only Display',
        shortName: null,
      );
      expect(r.label, 'Only Display');
    });
  });
}
