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
  TileLayer tileLayer() {
    final url = _urlTemplate(_provider);
    return TileLayer(
      urlTemplate: url,
      userAgentPackageName: 'com.pokatuha.app',
      maxZoom: 19,
    );
  }

  /// Tile URL template for the given provider. Public so tests can assert on
  /// exact URLs without instantiating a [TileLayer] (which requires Flutter).
  String urlTemplateFor(MapProvider provider) => _urlTemplate(provider);

  String _urlTemplate(MapProvider p) {
    switch (p) {
      case MapProvider.openStreetMap:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
      case MapProvider.cyclOSM:
        return 'https://{a-c}.tile-cyclosm.openstreetmap.fr/cyclosm/{z}/{x}/{y}.png';
      case MapProvider.openTopoMap:
        return 'https://{a-c}.tile.opentopomap.org/{z}/{x}/{y}.png';
      case MapProvider.esriSatellite:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/'
            'World_Imagery/MapServer/tile/{z}/{y}/{x}';
      case MapProvider.cartoVoyager:
        return 'https://{a-d}.basemaps.cartocdn.com/rastertiles/'
            'voyager/{z}/{x}/{y}.png';
      case MapProvider.mapLibre:
        return _customStyleUrl ??
            'https://demotiles.maplibre.org/style/{z}/{x}/{y}.png';
      // Deprecated non-V2 providers — spec forbids Google Maps; others stay
      // selectable for back-compat but render OSM tiles.
      case MapProvider.googleMaps:
      case MapProvider.here:
      case MapProvider.twoGis:
      case MapProvider.yandexMaps:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
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

  /// Deprecated non-V2 providers (kept for back-compat with persisted
  /// settings; selected ones fall back to OSM tiles).
  static const List<MapProvider> deprecatedProviders = [
    MapProvider.mapLibre,
    MapProvider.googleMaps,
    MapProvider.here,
    MapProvider.twoGis,
    MapProvider.yandexMaps,
  ];

  static const List<MapProvider> availableProviders = MapProvider.values;
}
