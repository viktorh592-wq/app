/// Route tab — route planning + GPX import/export (FR-008). Shows planned
/// routes on a map (OSM/MapLibre) and supports importing GPX files. The
/// route polyline uses the activity accent color (V2 §11 — propagation,
/// FIX_PLAN S2-T7).
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

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

  Future<void> _importGpx() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['gpx'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final content = file.bytes != null
          ? String.fromCharCodes(file.bytes!)
          : await File(file.path!).readAsString();
      final points = serviceLocator<GpxService>().parse(content);
      await serviceLocator<RouteRepository>().importGpx(
        eventId: widget.eventId,
        name: file.name.replaceAll(RegExp(r'\.gpx$', caseSensitive: false), ''),
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
            .showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'gpx_import_${widget.eventId}',
        onPressed: _importGpx,
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
                      onPressed: _importGpx,
                      icon: const Icon(Icons.file_upload_outlined),
                      label: Text(l.importGpx),
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
                Text(
                  '${(route.distanceMeters / 1000).toStringAsFixed(1)} km • ↑ ${route.elevationGainMeters.round()} m',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
