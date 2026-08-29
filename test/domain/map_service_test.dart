/// Sprint 4 — MapService unit tests (S4-T11). Verifies tile URL composition
/// for every V2 provider and the activity-context-aware default selection
/// (V2 MAPS_AND_GPS_FIX.md §1).
import 'package:flutter_test/flutter_test.dart';

import 'package:pokatuha/domain/enums/enums.dart';
import 'package:pokatuha/domain/services/map_service.dart';

void main() {
  final service = MapService();

  group('S4-T1 — tile URL composition for V2 providers', () {
    test('OpenStreetMap uses the standard OSM tile URL', () {
      final url = service.urlTemplateFor(MapProvider.openStreetMap);
      expect(url, 'https://tile.openstreetmap.org/{z}/{x}/{y}.png');
    });

    test('CyclOSM uses the cycling tile URL with subdomains', () {
      final url = service.urlTemplateFor(MapProvider.cyclOSM);
      expect(url, contains('tile-cyclosm.openstreetmap.fr'));
      expect(url, contains('{a-c}'));
      expect(url, contains('{z}/{x}/{y}.png'));
    });

    test('OpenTopoMap uses the relief tile URL with subdomains', () {
      final url = service.urlTemplateFor(MapProvider.openTopoMap);
      expect(url, contains('tile.opentopomap.org'));
      expect(url, contains('{a-c}'));
      expect(url, contains('{z}/{x}/{y}.png'));
    });

    test('Esri Satellite uses the ArcGIS World Imagery tile URL', () {
      final url = service.urlTemplateFor(MapProvider.esriSatellite);
      expect(url, contains('server.arcgisonline.com'));
      expect(url, contains('World_Imagery/MapServer/tile/{z}/{y}/{x}'));
    });

    test('Carto Voyager uses the Carto voyager tile URL with 4 subdomains',
        () {
      final url = service.urlTemplateFor(MapProvider.cartoVoyager);
      expect(url, contains('basemaps.cartocdn.com'));
      expect(url, contains('voyager'));
      expect(url, contains('{a-d}'));
    });

    test('deprecated non-V2 providers fall back to OSM tiles', () {
      for (final p in MapService.deprecatedProviders) {
        final url = service.urlTemplateFor(p);
        expect(url, 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            reason: '$p should fall back to OSM');
      }
    });

    test('v2Providers contains exactly the five V2 spec providers', () {
      expect(MapService.v2Providers, [
        MapProvider.openStreetMap,
        MapProvider.cyclOSM,
        MapProvider.openTopoMap,
        MapProvider.esriSatellite,
        MapProvider.cartoVoyager,
      ]);
    });
  });

  group('S4-T2 — context-aware default provider selection', () {
    test('cycling activity names map to CyclOSM', () {
      for (final name in [
        'MTB',
        'xc',
        'Enduro',
        'Downhill',
        'Gravel',
        'Road',
        'BMX',
        'E-Bike',
        'вело',
        'шоссе',
      ]) {
        expect(
          service.defaultProviderFor(name),
          MapProvider.cyclOSM,
          reason: '"$name" should default to CyclOSM',
        );
      }
    });

    test('mountain activity names map to OpenTopoMap', () {
      for (final name in [
        'Hiking',
        'Skiing',
        'Mountain',
        'Alpine',
        'поход',
        'горы',
      ]) {
        expect(
          service.defaultProviderFor(name),
          MapProvider.openTopoMap,
          reason: '"$name" should default to OpenTopoMap',
        );
      }
    });

    test('forest / water activity names map to Esri Satellite', () {
      for (final name in [
        'Forest',
        'Kayaking',
        'Water',
        'лес',
        'байдарка',
      ]) {
        expect(
          service.defaultProviderFor(name),
          MapProvider.esriSatellite,
          reason: '"$name" should default to Esri Satellite',
        );
      }
    });

    test('city activity names map to Carto Voyager', () {
      for (final name in ['Running', 'City', 'Urban', 'бег', 'город']) {
        expect(
          service.defaultProviderFor(name),
          MapProvider.cartoVoyager,
          reason: '"$name" should default to Carto Voyager',
        );
      }
    });

    test('unknown activity name falls back to OpenStreetMap', () {
      expect(
        service.defaultProviderFor('yoga'),
        MapProvider.openStreetMap,
      );
    });

    test('empty string falls back to OpenStreetMap', () {
      expect(
        service.defaultProviderFor(''),
        MapProvider.openStreetMap,
      );
    });

    test('matching is case-insensitive', () {
      expect(service.defaultProviderFor('mtb'), MapProvider.cyclOSM);
      expect(service.defaultProviderFor('MTB'), MapProvider.cyclOSM);
      expect(service.defaultProviderFor('Mtb'), MapProvider.cyclOSM);
    });
  });

  group('S4-T1 — setProvider / provider state', () {
    test('default provider is OpenStreetMap', () {
      final fresh = MapService();
      expect(fresh.provider, MapProvider.openStreetMap);
    });

    test('setProvider switches the active provider', () {
      final fresh = MapService();
      fresh.setProvider(MapProvider.esriSatellite);
      expect(fresh.provider, MapProvider.esriSatellite);
    });

    test('setProvider preserves customStyleUrl', () {
      final fresh = MapService();
      fresh.setProvider(MapProvider.mapLibre,
          styleUrl: 'https://example.com/style.json');
      expect(fresh.customStyleUrl, 'https://example.com/style.json');
    });
  });
}
