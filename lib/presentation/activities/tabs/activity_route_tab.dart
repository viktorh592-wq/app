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
        name: file.name.replaceAll(RegExp(r'\.(gpx|kml)$', caseSensitive: false), ''),
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
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: routes.length,
            itemBuilder: (context, i) => _RouteCard(
              route: routes[i],
              accentColor: widget.accentColor,
            ),
          );
        },
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.route, this.accentColor});

  final RouteCollection route;

  /// Activity accent color (V2 §11) — polyline color.
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    final points = route.waypoints.map((w) => LatLng(w.lat, w.lng)).toList();
    final center = points.isNotEmpty ? points.first : const LatLng(0, 0);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 160,
            child: FlutterMap(
              options: MapOptions(initialCenter: center, initialZoom: 13),
              children: [
                serviceLocator<MapService>().tileLayer(),
                if (points.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: points,
                        color: accentColor ?? DesignTokens.primary,
                        strokeWidth: 4,
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
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(route.name, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                // V2 §3 — distance + elevation + duration.
                Text(
                  _statsLabel(l),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                // V2 §5 — external handoff buttons.
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _openInNavigator(context),
                      icon: const Icon(Icons.directions_rounded, size: 18),
                      label: Text(l.openInNavigator),
                    ),
                    const SizedBox(width: 8),
                    if (route.gpxFilePath != null)
                      OutlinedButton.icon(
                        onPressed: () => _share(context),
                        icon: const Icon(Icons.ios_share_rounded, size: 18),
                        label: Text(l.share),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// V2 §3 — distance (km) + elevation (m) + duration (h m, when > 0).
  String _statsLabel(AppLocalizations l) {
    final km = (route.distanceMeters / 1000).toStringAsFixed(1);
    final elev = route.elevationGainMeters.round();
    if (route.durationSeconds > 0) {
      final hours = route.durationSeconds ~/ 3600;
      final mins = (route.durationSeconds % 3600) ~/ 60;
      final dur = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';
      return l.routeStatsWithDuration(km, '$elev', dur);
    }
    return l.routeStats(km, '$elev');
  }

  /// V2 §5 — "Открыть в навигаторе" via geo: URI (Android) or Apple Maps
  /// URL (iOS / other platforms where geo: is unsupported).
  Future<void> _openInNavigator(BuildContext context) async {
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

    // Android geo: URI — supports navigation with destination + start.
    // Most apps (Google Maps, Yandex, OsmAnd) register for geo:.
    final geoUri = Uri.parse(
        'geo:$lat,$lng?q=$lat,$lng&start=$sLat,$sLng&end=$eLat,$eLng');
    if (!kIsWeb && Platform.isAndroid) {
      if (await canLaunchUrl(geoUri)) {
        await launchUrl(geoUri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    // Fallback — Apple Maps / OSM web URL (works on iOS + web + desktop).
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
  Future<void> _share(BuildContext context) async {
    final path = route.gpxFilePath;
    if (path == null) return;
    try {
      await Share.shareXFiles([XFile(path)],
          text: route.name);
    } catch (e) {
      if (context.mounted) {
        final l = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${l.shareFailed}: $e')));
      }
    }
  }
}
