/// Map service — provider configuration and tile URLs (V2 MAPS_AND_GPS_FIX.md
/// §1). The V2 spec replaces the V1 vendor-specific providers (Google / HERE /
/// 2GIS / Yandex) with five natively-renderable tile sources:
///
///   • OpenStreetMap  — base / fallback, no API key
///   • CyclOSM        — cycling default, no API key
///   • OpenTopoMap    — relief / heights, no API key
///   • Esri Satellite — satellite, no API key
///   • Carto Voyager  — clean navigation, no API key
///
/// MapLibre is kept as a V1 provider for back-compat with persisted settings;
/// non-V2 providers (Google/HERE/2GIS/Yandex) are deprecated and fall back to
/// OSM tiles, but stay selectable so existing user settings keep working
/// (NFR-006 — No Vendor Lock-In).
library;

import 'package:flutter_map/flutter_map.dart';

import 'package:pokatuha/domain/enums/enums.dart';

class MapService {
  MapProvider _provider = MapProvider.openStreetMap;
  String? _customStyleUrl;

  MapProvider get provider => _provider;
  String? get customStyleUrl => _customStyleUrl;

  void setProvider(MapProvider provider, {String? styleUrl}) {
    _provider = provider;
    _customStyleUrl = styleUrl;
  }

  /// V2 tile layer for the active provider. All five V2 providers are rendered
  /// natively via flutter_map. Non-V2 providers fall back to OSM tiles
  /// (No Vendor Lock-In — selection is still persisted).
  ///
  /// V3.0.1 bug fix — flutter_map 7.x only expands the `{s}` placeholder
  /// (with the `subdomains` parameter). The previous code used `{a-c}` /
  /// `{a-d}` ranges which were never expanded, so the URL was passed
  /// literally to the tile server and produced 404s for CyclOSM,
  /// OpenTopoMap and Carto Voyager. The URLs are now `{s}`-based and each
  /// provider gets its own `subdomains` list (CyclOSM/OpenTopoMap share
  /// `a/b/c`, Carto Voyager uses `a/b/c/d`).
  TileLayer tileLayer() {
    final cfg = _tileConfig(_provider);
    return TileLayer(
      urlTemplate: cfg.urlTemplate,
      subdomains: cfg.subdomains,
      userAgentPackageName: 'com.pokatuha.app',
      maxZoom: 19,
    );
  }

  /// Tile URL template for the given provider. Public so tests can assert on
  /// exact URLs without instantiating a [TileLayer] (which requires Flutter).
  String urlTemplateFor(MapProvider provider) => _tileConfig(provider).urlTemplate;

  /// Subdomains for the `{s}` placeholder of the given provider. Public so
  /// tests can assert on the subdomain list (V3.0.1 fix).
  List<String> subdomainsFor(MapProvider provider) => _tileConfig(provider).subdomains;

  /// Tile URL + subdomain list for a provider (V3.0.1 fix).
  _TileConfig _tileConfig(MapProvider p) {
    switch (p) {
      case MapProvider.openStreetMap:
        // No CDN subdomains — single origin.
        return const _TileConfig(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: _noSubdomains,
        );
      case MapProvider.cyclOSM:
        return const _TileConfig(
          urlTemplate:
              'https://{s}.tile-cyclosm.openstreetmap.fr/cyclosm/{z}/{x}/{y}.png',
          subdomains: _abcSubdomains,
        );
      case MapProvider.openTopoMap:
        return const _TileConfig(
          urlTemplate: 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
          subdomains: _abcSubdomains,
        );
      case MapProvider.esriSatellite:
        // ArcGIS World Imagery — single origin (no CDN subdomain), Y/X tile
        // order is the ArcGIS convention. flutter_map's URL templating is
        // placeholder-based, so `{z}/{y}/{x}` works verbatim.
        return const _TileConfig(
          urlTemplate:
              'https://server.arcgisonline.com/ArcGIS/rest/services/'
              'World_Imagery/MapServer/tile/{z}/{y}/{x}',
          subdomains: _noSubdomains,
        );
      case MapProvider.cartoVoyager:
        return const _TileConfig(
          urlTemplate:
              'https://{s}.basemaps.cartocdn.com/rastertiles/'
              'voyager/{z}/{x}/{y}.png',
          subdomains: _abcdSubdomains,
        );
      case MapProvider.mapLibre:
        return _TileConfig(
          urlTemplate: _customStyleUrl ??
              'https://demotiles.maplibre.org/style/{z}/{x}/{y}.png',
          subdomains: _noSubdomains,
        );
      // Deprecated non-V2 providers — spec forbids Google Maps; others stay
      // selectable for back-compat but render OSM tiles.
      case MapProvider.googleMaps:
      case MapProvider.here:
      case MapProvider.twoGis:
      case MapProvider.yandexMaps:
        return const _TileConfig(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: _noSubdomains,
        );
    }
  }

  /// V2 MAPS_AND_GPS_FIX.md §1 — default-by-context selection. Used when the
  /// user has not picked a provider explicitly (e.g. on first map entry, or
  /// when opening the map from an activity of a known type).
  ///
  ///   Cycling (MTB / XC / Enduro / Downhill / Gravel / Road / BMX / E-Bike)
  ///     → CyclOSM
  ///   Mountains / Hiking / Skiing → OpenTopoMap
  ///   Forest / Kayaking           → Esri Satellite
  ///   Running / City              → Carto Voyager
  ///   Fallback                    → OpenStreetMap
  MapProvider defaultProviderFor(String activityTypeName) {
    final n = activityTypeName.toLowerCase();
    if (_cyclingActivities.any(n.contains)) return MapProvider.cyclOSM;
    if (_mountainActivities.any(n.contains)) return MapProvider.openTopoMap;
    if (_forestActivities.any(n.contains)) return MapProvider.esriSatellite;
    if (_cityActivities.any(n.contains)) return MapProvider.cartoVoyager;
    return MapProvider.openStreetMap;
  }

  static const List<String> _cyclingActivities = [
    'mtb',
    'xc',
    'enduro',
    'downhill',
    'gravel',
    'road',
    'bmx',
    'e-bike',
    'ebike',
    'cycling',
    'bike',
    'вело',
    'маунтинбайк',
    'шоссе',
    'кросс-кантри',
    'эндуро',
    'даунхилл',
    'гравий',
    'bmх',
  ];

  static const List<String> _mountainActivities = [
    'hiking',
    'skiing',
    'mountain',
    'mountains',
    'trek',
    'alpine',
    'hike',
    'скитур',
    'горный',
    'горы',
    'поход',
    'альпинизм',
  ];

  static const List<String> _forestActivities = [
    'forest',
    'kayaking',
    'kayak',
    'water',
    'rafting',
    'лес',
    'лесной',
    'байдарка',
    'каяк',
    'сплав',
  ];

  static const List<String> _cityActivities = [
    'running',
    'run',
    'city',
    'urban',
    'бег',
    'город',
    'городской',
  ];

  /// V2 providers only — used by the layer switcher UI (S4-T3).
  static const List<MapProvider> v2Providers = [
    MapProvider.openStreetMap,
    MapProvider.cyclOSM,
    MapProvider.openTopoMap,
    MapProvider.esriSatellite,
    MapProvider.cartoVoyager,
  ];

  /// Deprecated non-V2 providers — kept for back-compat with persisted
  /// settings; selected ones fall back to OSM tiles.
  ///
  /// Note: `mapLibre` is NOT in this list — it's the V1 default-style
  /// option and renders its own demotiles URL. Only the V1 vendor-specific
  /// providers (Google / HERE / 2GIS / Yandex) that V2 explicitly forbids
  /// are deprecated.
  static const List<MapProvider> deprecatedProviders = [
    MapProvider.googleMaps,
    MapProvider.here,
    MapProvider.twoGis,
    MapProvider.yandexMaps,
  ];

  static const List<MapProvider> availableProviders = MapProvider.values;

  /// Empty subdomain list — used by single-origin providers (OSM, Esri,
  /// MapLibre demotiles). flutter_map's `TileLayer` accepts an empty list
  /// and skips the `{s}` expansion in that case (the URL template must not
  /// contain `{s}` either).
  static const List<String> _noSubdomains = [];

  /// `a` / `b` / `c` subdomain rotation — used by CyclOSM and OpenTopoMap.
  static const List<String> _abcSubdomains = ['a', 'b', 'c'];

  /// `a` / `b` / `c` / `d` subdomain rotation — used by Carto Voyager.
  static const List<String> _abcdSubdomains = ['a', 'b', 'c', 'd'];
}

/// Tile URL + subdomains for a single provider (V3.0.1 fix).
class _TileConfig {
  const _TileConfig({
    required this.urlTemplate,
    required this.subdomains,
  });

  final String urlTemplate;
  final List<String> subdomains;
}
