/// Map picker — choose the activity meeting point (V3.0.4 — bug 3).
///
/// The «точка сбора» field icon previously ran a silent GPS default setter,
/// which the user perceived as «нажимаю — и ничего не происходит». This
/// page provides the expected behaviour:
///   * an interactive OSM map (the app's configured [MapService] tiles);
///   * tap anywhere to move the marker;
///   * an address search field (Nominatim, debounced) with result chips;
///   * a «my location» shortcut (Geolocator);
///   * reverse geocoding of the selected point so the meeting point field
///     can store a readable ADDRESS (user requirement) instead of raw
///     coordinates.
///
/// Returns a [MapPickResult] (or null when cancelled) to the caller.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'package:pokatuha/domain/services/geocoding_service.dart';
import 'package:pokatuha/domain/services/map_service.dart';
import 'package:pokatuha/domain/services/service_locator.dart';
import 'package:pokatuha/l10n/app_localizations.dart';

/// The picked meeting point handed back to the caller.
class MapPickResult {
  const MapPickResult({
    required this.lat,
    required this.lng,
    required this.label,
  });

  final double lat;
  final double lng;

  /// Human-readable address (or «Координаты» fallback when offline).
  final String label;
}

class MapPickerPage extends StatefulWidget {
  const MapPickerPage({
    super.key,
    this.initialLat,
    this.initialLng,
  });

  /// The previously selected point (if any) — the picker starts there.
  final double? initialLat;
  final double? initialLng;

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  final GeocodingService _geocoding = serviceLocator<GeocodingService>();

  AppLocalizations get l10n => AppLocalizations.of(context)!;

  Timer? _searchDebounce;
  Timer? _reverseDebounce;

  List<GeoSuggestion> _suggestions = [];
  bool _searching = false;
  bool _resolvingAddress = false;
  bool _locating = false;

  LatLng _point = const LatLng(55.7558, 37.6173); // fallback: Moscow centre
  String _address = '';

  bool _hasInitialPoint = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      _point = LatLng(widget.initialLat!, widget.initialLng!);
      _hasInitialPoint = true;
      // Resolve the stored point's address for the confirmation bar.
      _resolveAddress(_point);
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _reverseDebounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------
  // Interactions
  // -------------------------------------------------------------------

  void _onMapTap(TapPosition _, LatLng point) {
    _searchFocus.unfocus();
    setState(() {
      _point = point;
      _suggestions = [];
      _address = '';
      _resolvingAddress = true;
    });
    _reverseDebounce?.cancel();
    // Debounce reverse lookups: dragging/tapping several times must not
    // fire one Nominatim request per tap.
    _reverseDebounce = Timer(const Duration(milliseconds: 500), () {
      _resolveAddress(point);
    });
  }

  Future<void> _resolveAddress(LatLng point) async {
    final address = await _geocoding.reverse(lat: point.latitude, lng: point.longitude);
    if (!mounted) return;
    // Ignore stale responses (the user already picked another point).
    if (point != _point) return;
    setState(() {
      _resolvingAddress = false;
      _address = address ?? AppLocalizations.of(context)!.addressUnavailable;
    });
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().length < 3) {
      setState(() => _suggestions = []);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 600), () {
      _runSearch(query);
    });
  }

  Future<void> _runSearch(String query) async {
    setState(() => _searching = true);
    final results = await _geocoding.search(query, limit: 5);
    if (!mounted) return;
    if (results == null) {
      // Network/server failure — tell the user, keep the previous list.
      setState(() {
        _searching = false;
        _suggestions = [];
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.mapSearchError)));
      return;
    }
    if (results.isEmpty) {
      setState(() {
        _searching = false;
        _suggestions = [];
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.mapSearchNoResults)));
      return;
    }
    setState(() {
      _searching = false;
      _suggestions = results;
    });
  }

  void _applySuggestion(GeoSuggestion suggestion) {
    _searchFocus.unfocus();
    final point = LatLng(suggestion.lat, suggestion.lng);
    setState(() {
      _point = point;
      _address = suggestion.displayName;
      _suggestions = [];
      _searchController.text = suggestion.displayName;
    });
    _mapController.move(point, 16);
  }

  Future<void> _moveToMyLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      final point = LatLng(position.latitude, position.longitude);
      if (!mounted) return;
      setState(() => _point = point);
      _mapController.move(point, 15);
      _resolveAddress(point);
    } catch (_) {
      // GPS unavailable / permission denied — keep the current view.
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _confirm() {
    Navigator.of(context).pop(MapPickResult(
      lat: _point.latitude,
      lng: _point.longitude,
      label: _address.isNotEmpty &&
              _address != AppLocalizations.of(context)!.addressUnavailable
          ? _address
          : '${_point.latitude.toStringAsFixed(5)}, '
              '${_point.longitude.toStringAsFixed(5)}',
    ));
  }

  // -------------------------------------------------------------------
  // UI
  // -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.meetingPointPick)),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _point,
              initialZoom: _hasInitialPoint ? 16 : 10,
              onTap: _onMapTap,
            ),
            children: [
              serviceLocator<MapService>().tileLayer(),
              MarkerLayer(markers: [_marker(theme)]),
            ],
          ),
          // Search field on top.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    decoration: InputDecoration(
                      hintText: l.mapSearchHint,
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              ),
                            )
                          : (_searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close_rounded),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _suggestions = []);
                                  },
                                )
                              : null),
                      isDense: true,
                      filled: true,
                      fillColor: theme.colorScheme.surface.withOpacity(0.95),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: _onSearchChanged,
                  ),
                  if (_suggestions.isNotEmpty)
                    Card(
                      elevation: 4,
                      margin: const EdgeInsets.only(top: 8),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _suggestions.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final s = _suggestions[i];
                          return ListTile(
                            dense: true,
                            leading:
                                const Icon(Icons.place_outlined, size: 20),
                            title: Text(
                              s.displayName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                            onTap: () => _applySuggestion(s),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          // My location shortcut.
          Positioned(
            right: 12,
            bottom: 130,
            child: FloatingActionButton.small(
              heroTag: 'picker-my-location',
              tooltip: l10n.mapMyLocation,
              onPressed: _locating ? null : _moveToMyLocation,
              child: _locating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location_rounded),
            ),
          ),
          // Confirmation bar with the address of the picked point.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l.mapPickHint,
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _resolvingAddress
                          ? l.mapLoadingAddress
                          : _address.isNotEmpty
                              ? _address
                              : '${_point.latitude.toStringAsFixed(5)}, '
                                  '${_point.longitude.toStringAsFixed(5)}',
                      style: theme.textTheme.titleSmall,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: _confirm,
                      icon: const Icon(Icons.check_rounded),
                      label: Text(l.mapConfirm),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Marker _marker(ThemeData theme) {
    return Marker(
      point: _point,
      width: 44,
      height: 44,
      child: Icon(
        Icons.location_on_rounded,
        size: 44,
        color: theme.colorScheme.primary,
        shadows: const [
          Shadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
    );
  }
}
