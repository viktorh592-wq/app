/// Route tab — route planning + GPX/KML import/export (FR-008). Shows planned
/// routes on a map (OSM/MapLibre) and supports importing GPX and KML files.
/// The route polyline uses the activity accent color (V2 §11 — propagation,
/// FIX_PLAN S2-T7).
///
/// V3 Sprint 5 (FIX_PLAN S5-T7, S5-T10) — V2 ROUTES_IMPORT.md:
///   • §1 multi-format import (.gpx / .kml; .fit rejected with a clear
///     message — proprietary binary, out of scope)
///   • §3 route card now shows distance + elevation + duration
///   • §5 external handoff — "Открыть в навигаторе" via geo: URI +
///     "Поделиться" via system share sheet
///
/// V3 fix (user-reported): the route map now fills all available screen
/// space (Expanded) with the action buttons pinned below it. When several
/// routes exist, a dropdown at the top lets the user switch between them
/// without leaving the full-screen map. Previously each route lived in a
/// small 160-px card inside a scrollable list, which wasted the screen.
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:pokatuha/core/errors/app_error.dart';
import 'package:pokatuha/core/tokens/design_tokens.dart';
import 'package:pokatuha/database/collections/route_collection.dart';
import 'package:pokatuha/domain/repositories/route_repository.dart';
import 'package:pokatuha/domain/services/gpx_service.dart';
import 'package:pokatuha/domain/services/map_service.dart';
import 'package:pokatuha/domain/services/service_locator.dart';
import 'package:pokatuha/l10n/app_localizations.dart';
import 'package:pokatuha/presentation/widgets/elevation_profile_chart.dart';

class ActivityRouteTab extends StatefulWidget {
  const ActivityRouteTab({super.key, required this.eventId, this.accentColor});

  final String eventId;

  /// Activity accent color (V2 §11).
  final Color? accentColor;

  @override
  State<ActivityRouteTab> createState() => _ActivityRouteTabState();
}

class _ActivityRouteTabState extends State<ActivityRouteTab> {
  late Future<List<RouteCollection>> _future;
  final MapController _mapController = MapController();
  int _selectedIndex = 0;
  bool _initialFitDone = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = serviceLocator<RouteRepository>().byEvent(widget.eventId);
  }

  /// V2 §1 — accept .gpx and .kml; reject .fit with a localized message.
  Future<void> _importFile() async {
    final l = AppLocalizations.of(context)!;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['gpx', 'kml', 'fit'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final ext = (file.extension ?? '').toLowerCase();
      if (ext == 'fit') {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(l.fitNotSupported)));
        }
        return;
      }
      if (ext != 'gpx' && ext != 'kml') {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(l.unsupportedFormat)));
        }
        return;
      }
      final content = file.bytes != null
          ? String.fromCharCodes(file.bytes!)
          : await File(file.path!).readAsString();
      final points = serviceLocator<GpxService>()
          .parseForExtension(content, ext);
      await serviceLocator<RouteRepository>().importGpx(
        eventId: widget.eventId,
        name: file.name.replaceAll(
            RegExp(r'\.(gpx|kml)$', caseSensitive: false), ''),
        waypoints: points,
        gpxFilePath: file.path ?? file.name,
      );
      if (mounted) setState(_load);
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${l.importFailed}: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'route_import_${widget.eventId}',
        onPressed: _importFile,
        child: const Icon(Icons.file_upload_outlined),
      ),
      body: FutureBuilder<List<RouteCollection>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final routes = snapshot.data!;
          if (routes.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.route_outlined, size: 56),
                    const SizedBox(height: 12),
                    Text(l.addRoute),
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      onPressed: _importFile,
                      icon: const Icon(Icons.file_upload_outlined),
                      label: Text(l.importRoute),
                    ),
                  ],
                ),
              ),
            );
          }
          final route = routes[_selectedIndex.clamp(0, routes.length - 1)];
          return _FullScreenRouteView(
            route: route,
            routes: routes,
            accentColor: widget.accentColor,
            mapController: _mapController,
            onSelected: (i) => setState(() {
              _selectedIndex = i;
              _initialFitDone = false;
            }),
            onImport: _importFile,
            initialFitDone: _initialFitDone,
            onFitDone: () => _initialFitDone = true,
          );
        },
      ),
    );
  }
}

/// Full-screen route view — map fills the available area (Expanded) with
/// the action buttons (Open in navigator / Share / Import) + elevation
/// profile pinned below. A dropdown at the top lets the user switch
/// between routes when more than one exists.
class _FullScreenRouteView extends StatelessWidget {
  const _FullScreenRouteView({
    required this.route,
    required this.routes,
    required this.accentColor,
    required this.mapController,
    required this.onSelected,
    required this.onImport,
    required this.initialFitDone,
    required this.onFitDone,
  });

  final RouteCollection route;
  final List<RouteCollection> routes;
  final Color? accentColor;
  final MapController mapController;
  final ValueChanged<int> onSelected;
  final VoidCallback onImport;
  final bool initialFitDone;
  final VoidCallback onFitDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    final points = route.waypoints.map((w) => LatLng(w.lat, w.lng)).toList();
    final center = points.isNotEmpty ? points.first : const LatLng(0, 0);

    // Fit camera to route bounds once after the route changes.
    if (!initialFitDone && points.length >= 2) {
      onFitDone();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(points),
            padding: const EdgeInsets.all(48),
          ),
        );
      });
    }

    return SafeArea(
      child: Column(
        children: [
          // Top bar — route selector (only when more than one) + import.
          if (routes.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: routes.indexOf(route).clamp(0, routes.length - 1),
                      decoration: InputDecoration(
                        isDense: true,
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        prefixIcon: const Icon(Icons.route_rounded, size: 20),
                      ),
                      items: routes
                          .asMap()
                          .entries
                          .map((e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value.name,
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) onSelected(v);
                      },
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(
                children: [
                  Icon(Icons.route_rounded,
                      size: 20, color: accentColor ?? DesignTokens.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(route.name,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),

          // Full-screen map — Expanded to take all remaining vertical space
          // above the buttons + elevation chart.
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
                child: FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: 13,
                    minZoom: 3,
                    maxZoom: 19,
                  ),
                  children: [
                    serviceLocator<MapService>().tileLayer(),
                    if (points.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: points,
                            color: accentColor ?? DesignTokens.primary,
                            strokeWidth: 5,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        if (points.isNotEmpty)
                          Marker(
                            point: points.first,
                            width: 30,
                            height: 30,
                            child: const Icon(Icons.flag_rounded,
                                color: Colors.green, size: 28),
                          ),
                        if (points.length > 1)
                          Marker(
                            point: points.last,
                            width: 30,
                            height: 30,
                            child: const Icon(Icons.flag_rounded,
                                color: Colors.red, size: 28),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Below-the-map block — stats, action buttons, elevation profile.
          // Flexible so it shrinks if the map needs more room; scrolls
          // internally if the elevation chart + buttons don't fit.
          Flexible(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(_statsLabel(l, route),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.outline)),
                    const SizedBox(height: 8),
                    // Action row — "Open in navigator" + "Share" + "Import".
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _openInNavigator(context, route),
                          icon: const Icon(Icons.directions_rounded, size: 18),
                          label: Text(l.openInNavigator),
                        ),
                        if (route.gpxFilePath != null)
                          OutlinedButton.icon(
                            onPressed: () => _share(context, route),
                            icon:
                                const Icon(Icons.ios_share_rounded, size: 18),
                            label: Text(l.share),
                          ),
                        OutlinedButton.icon(
                          onPressed: onImport,
                          icon: const Icon(Icons.file_upload_outlined,
                              size: 18),
                          label: Text(l.importRoute),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Elevation profile chart — «Высоты».
                    ElevationProfileChart(
                      points: route.waypoints,
                      accentColor: accentColor,
                      height: 140,
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

  /// V2 §3 — distance (km) + elevation (m) + duration (ч мин, when > 0).
  String _statsLabel(AppLocalizations l, RouteCollection route) {
    final km = (route.distanceMeters / 1000).toStringAsFixed(1);
    final elev = route.elevationGainMeters.round();
    if (route.durationSeconds > 0) {
      final hours = route.durationSeconds ~/ 3600;
      final mins = (route.durationSeconds % 3600) ~/ 60;
      final dur = hours > 0 ? '$hours ч $mins мин' : '$mins мин';
      return l.routeStatsWithDuration(km, '$elev', dur);
    }
    return l.routeStats(km, '$elev');
  }

  /// V2 §5 — "Открыть в навигаторе" via geo: URI (Android) or Apple Maps
  /// URL (iOS / other platforms where geo: is unsupported).
  Future<void> _openInNavigator(
      BuildContext context, RouteCollection route) async {
    final pts = route.waypoints;
    if (pts.isEmpty) return;
    final first = pts.first;
    final last = pts.length > 1 ? pts.last : first;
    final mid = pts[pts.length ~/ 2];
    final lat = mid.lat.toStringAsFixed(6);
    final lng = mid.lng.toStringAsFixed(6);
    final sLat = first.lat.toStringAsFixed(6);
    final sLng = first.lng.toStringAsFixed(6);
    final eLat = last.lat.toStringAsFixed(6);
    final eLng = last.lng.toStringAsFixed(6);

    final geoUri = Uri.parse(
        'geo:$lat,$lng?q=$lat,$lng&start=$sLat,$sLng&end=$eLat,$eLng');
    if (!kIsWeb && Platform.isAndroid) {
      if (await canLaunchUrl(geoUri)) {
        await launchUrl(geoUri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    final mapsUrl = Uri.parse(
        'https://www.openstreetmap.org/?mlat=$lat&mlon=$lng#map=14/$lat/$lng');
    if (await canLaunchUrl(mapsUrl)) {
      await launchUrl(mapsUrl, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        final l = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.noNavigatorApp)));
      }
    }
  }

  /// V2 §5 — "Поделиться" via system share sheet.
  Future<void> _share(BuildContext context, RouteCollection route) async {
    final path = route.gpxFilePath;
    if (path == null) return;
    try {
      await Share.shareXFiles([XFile(path)], text: route.name);
    } catch (e) {
      if (context.mounted) {
        final l = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${l.shareFailed}: $e')));
      }
    }
  }
}
