/// Mini route map preview for activity cards (V2 GROUPS_AND_ACTIVITIES.md §8,
/// FIX_PLAN S2-T5). A fixed-size, non-interactive flutter_map showing the
/// route polyline and the meeting point — decorative only, taps pass through
/// to the parent card's GestureDetector.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:pokatuha/core/tokens/design_tokens.dart';
import 'package:pokatuha/database/collections/embedded/geo_point.dart';
import 'package:pokatuha/database/collections/route_collection.dart';
import 'package:pokatuha/domain/services/map_service.dart';
import 'package:pokatuha/domain/services/service_locator.dart';

class MiniMapPreview extends StatelessWidget {
  const MiniMapPreview({
    super.key,
    required this.route,
    this.meetingPoint,
    this.routeColor,
  });

  /// Route whose waypoints are drawn as a polyline.
  final RouteCollection route;

  /// Activity meeting point marker (fallback center when no waypoints).
  final GeoPoint? meetingPoint;

  /// Polyline color — activity accent (V2 §11 color propagation).
  final Color? routeColor;

  @override
  Widget build(BuildContext context) {
    final points = route.waypoints.map((w) => LatLng(w.lat, w.lng)).toList();
    final center = points.isNotEmpty
        ? points.first
        : (meetingPoint != null
            ? LatLng(meetingPoint!.lat, meetingPoint!.lng)
            : const LatLng(0, 0));
    return IgnorePointer(
      child: FlutterMap(
        options: MapOptions(
          initialCenter: center,
          initialZoom: 13,
          interactionOptions:
              const InteractionOptions(flags: InteractiveFlag.none),
        ),
        children: [
          serviceLocator<MapService>().tileLayer(),
          if (points.isNotEmpty)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: points,
                  color: routeColor ?? DesignTokens.primary,
                  strokeWidth: 4,
                ),
              ],
            ),
          MarkerLayer(
            markers: [
              if (meetingPoint != null)
                Marker(
                  point: LatLng(meetingPoint!.lat, meetingPoint!.lng),
                  width: 24,
                  height: 24,
                  child: const Icon(
                    Icons.place_rounded,
                    color: Colors.red,
                    size: 24,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
