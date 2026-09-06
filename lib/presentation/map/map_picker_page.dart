/// Map picker page — lets the user choose a meeting point by:
///   • tapping on the map (reverse-geocoded to a human address)
///   • searching for an address (forward geocoding via Nominatim)
///   • confirming the current selection
///
/// Returns a [MapPickerResult] via `Navigator.pop(result)`. The caller
/// (CreateActivityPage / EditActivity) stores the lat/lng into the event
/// and the address label into the meeting-point text field.
///
/// Bug 3 (V3.0.3): previously tapping the map icon in CreateActivityPage
/// silently set the meeting point to the user's current GPS (or to a Kyiv
/// fallback) and never opened a map. The user expects an explicit picker.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:pokatuha/core/tokens/design_tokens.dart';
import 'package:pokatuha/domain/services/geocoding_service.dart';
import 'package:pokatuha/domain/services/gps_service.dart';
import 'package:pokatuha/domain/services/map_service.dart';
import 'package:pokatuha/domain/services/service_locator.dart';
import 'package:pokatuha/l10n/app_localizations.dart';

/// Result returned by the map picker.
class MapPickerResult {
  MapPickerResult({
    required this.lat,
    required this.lng,
    required this.label,
  });

  final double lat;
  final double lng;

  /// Human-readable address (or "lat, lng" when geocoding failed).
  final String label;
}

class MapPickerPage extends StatefulWidget {
  const MapPickerPage({
    super.key,
    this.initialLatLng,
    this.initialLabel,
  });

  /// Optional initial marker position (used when editing an activity).
  final LatLng? initialLatLng;

  /// Optional initial address label (used when editing).
  final String? initialLabel;

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  /// Currently selected position. Null until the user taps the map or picks
  /// a search result.
  LatLng? _selected;

  /// Currently displayed label for [_selected] (may be a placeholder while
  /// reverse-geocoding is in flight).
  String _selectedLabel = '';

  /// Search results from the latest Nominatim /search call.
  List<GeocodingResult> _results = const <GeocodingResult>[];

  /// True while a search request is in flight (drives the trailing loader).
  bool _searching = false;

  /// True while reverse-geocoding the latest tap (drives the bottom-bar
  /// progress indicator).
  bool _reverseLoading = false;

  /// Search debounce — Nominatim policy: max 1 req/sec. We also avoid
  /// spamming on every keystroke.
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (widget.initialLatLng != null) {
      _selected = widget.initialLatLng;
      _selectedLabel = widget.initialLabel ?? '';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  /// Forward-geocoding entry point. Debounced by 700ms to coalesce typing
  /// bursts into a single Nominatim request.
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), () {
      _runSearch(value);
    });
  }

  Future<void> _runSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        _results = const <GeocodingResult>[];
      });
      return;
    }
    setState(() => _searching = true);
    try {
      final list = await serviceLocator<GeocodingService>().search(q, limit: 6);
      if (mounted) {
        setState(() {
          _results = list;
          _searching = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _searching = false;
          _results = const <GeocodingResult>[];
        });
      }
    }
  }

  /// Pick a search result: drop a marker, fly the map, reverse-geocode to
  /// refresh the label (the search result already has a label but reverse
  /// geocoding produces a consistent format).
  Future<void> _selectResult(GeocodingResult r) async {
    final ll = LatLng(r.lat, r.lng);
    setState(() {
      _selected = ll;
      _selectedLabel = r.label.isEmpty ? r.displayName : r.label;
      _results = const <GeocodingResult>[];
      _searchController.text = _selectedLabel;
      _reverseLoading = false;
    });
    _mapController.move(ll, 16);
  }

  /// Tap on the map → drop a marker and reverse-geocode the coordinate.
  Future<void> _onMapTap(TapPosition tap, LatLng point) async {
    setState(() {
      _selected = point;
      _selectedLabel =
          '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
      _reverseLoading = true;
    });
    try {
      final result = await serviceLocator<GeocodingService>()
          .reverse(point.latitude, point.longitude);
      if (mounted) {
        setState(() {
          _reverseLoading = false;
          if (result != null) {
            final label = result.label.isEmpty ? result.displayName : result.label;
            _selectedLabel = label.isEmpty ? _selectedLabel : label;
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _reverseLoading = false);
    }
  }

  /// "Find me" FAB action — request current GPS and centre the map on it.
  Future<void> _findMe() async {
    try {
      final sample = await serviceLocator<GpsService>().current();
      final ll = LatLng(sample.lat, sample.lng);
      _mapController.move(ll, 15);
      await _onMapTap(const TapPosition(Offset.zero, Offset.zero), ll);
    } catch (_) {
      // GPS unavailable — silently ignore, the user can still tap on the map.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.locationUnavailable)),
        );
      }
    }
  }

  /// Confirm and return the selected location to the caller.
  void _confirm() {
    final sel = _selected;
    if (sel == null) return;
    Navigator.of(context).pop(MapPickerResult(
      lat: sel.latitude,
      lng: sel.longitude,
      label: _selectedLabel,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.mapPickerTitle),
        actions: [
          IconButton(
            tooltip: l.findMe,
            icon: const Icon(Icons.my_location_rounded),
            onPressed: _findMe,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar.
          Padding(
            padding: const EdgeInsets.fromLTRB(
                DesignTokens.space3, DesignTokens.space2, DesignTokens.space3, DesignTokens.space2),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: l.mapPickerSearchHint,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : (_searchController.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _results = const <GeocodingResult>[]);
                            },
                          )),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
                ),
              ),
            ),
          ),
          if (_results.isNotEmpty)
            Material(
              elevation: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  itemBuilder: (context, i) {
                    final r = _results[i];
                    final title = r.label;
                    final subtitle = r.displayName.isEmpty || r.displayName == title
                        ? null
                        : r.displayName;
                    return ListTile(
                      leading: const Icon(Icons.place_outlined),
                      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: subtitle == null
                          ? null
                          : Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                      onTap: () => _selectResult(r),
                    );
                  },
                ),
              ),
            ),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: widget.initialLatLng ?? const LatLng(50.4501, 30.5234),
                initialZoom: widget.initialLatLng == null ? 5 : 14,
                onTap: _onMapTap,
              ),
              children: [
                serviceLocator<MapService>().tileLayer(),
                if (_selected != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _selected!,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.redAccent,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          // Bottom bar — selected address + confirm button.
          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                  DesignTokens.space4, DesignTokens.space3, DesignTokens.space4, DesignTokens.space3),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 0.5,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.place_rounded, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _reverseLoading
                            ? Row(
                                children: [
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(l.mapPickerResolving),
                                ],
                              )
                            : Text(
                                _selected == null
                                    ? l.mapPickerHint
                                    : (_selectedLabel.isEmpty
                                        ? '${_selected!.latitude.toStringAsFixed(5)}, '
                                            '${_selected!.longitude.toStringAsFixed(5)}'
                                        : _selectedLabel),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: DesignTokens.space2),
                  FilledButton.icon(
                    onPressed: _selected == null ? null : _confirm,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(l.confirm),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
