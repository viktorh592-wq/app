/// Map service — provider configuration and tile URLs (Maps rules). Default
/// OpenStreetMap / MapLibre; user may select another provider. The
/// architecture must support future providers without redesign (NFR-006).
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

  /// Tile layer for the active provider. Only OpenStreetMap and MapLibre are
  /// rendered natively via flutter_map; other providers are handled by their
  /// own SDKs (future) but remain selectable (No Vendor Lock-In).
  TileLayer tileLayer() {
    switch (_provider) {
      case MapProvider.openStreetMap:
        return TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.pokatuha.app',
          maxZoom: 19,
        );
      case MapProvider.mapLibre:
        return TileLayer(
          urlTemplate: _customStyleUrl ??
              'https://demotiles.maplibre.org/style/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.pokatuha.app',
          maxZoom: 19,
        );
      case MapProvider.googleMaps:
      case MapProvider.here:
      case MapProvider.twoGis:
      case MapProvider.yandexMaps:
        // Non-native providers fall back to OSM tiles until their dedicated
        // SDK integrations are added; selection is still persisted (NFR-006).
        return TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.pokatuha.app',
          maxZoom: 19,
        );
    }
  }

  static const List<MapProvider> availableProviders = MapProvider.values;
}
