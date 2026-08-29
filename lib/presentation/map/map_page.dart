/// Map tab — V2 map providers via flutter_map (MAPS_AND_GPS_FIX.md). Shows
/// activity meeting points and live participant positions (FR-005).
/// FAB opens the map action menu with the six V2 actions (§5): find me,
/// share location, show route, download GPX, select map, show participants.
///
/// V2 Sprint 4 (S4-T1..T6):
///   • Layer switcher offers all five V2 providers (CyclOSM, OpenTopoMap,
///     Esri Satellite, Carto Voyager, OpenStreetMap) with localized labels.
///   • Participant marker is a circular avatar ringed with the activity
///     accent color, with a heading arrow and a speed badge (§4).
///   • Tapping a participant marker opens a popup sheet with name, status,
///     speed, distance-to-me, heading text, battery % (§4).
///   • When zoomed out, overlapping participant markers are clustered
///     into a single count badge (§6).
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' hide Path;
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:pokatuha/core/errors/app_error.dart';
import 'package:pokatuha/core/tokens/design_tokens.dart';
import 'package:pokatuha/core/utils/geo_utils.dart';
import 'package:pokatuha/database/collections/event_collection.dart';
import 'package:pokatuha/database/collections/participant_collection.dart';
import 'package:pokatuha/database/collections/route_collection.dart';
import 'package:pokatuha/domain/enums/enums.dart';
import 'package:pokatuha/domain/repositories/event_repository.dart';
import 'package:pokatuha/domain/repositories/participant_repository.dart';
import 'package:pokatuha/domain/repositories/route_repository.dart';
import 'package:pokatuha/domain/repositories/user_repository.dart';
import 'package:pokatuha/domain/services/foreground_location_service.dart';
import 'package:pokatuha/domain/services/gps_service.dart';
import 'package:pokatuha/domain/services/gpx_service.dart';
import 'package:pokatuha/domain/services/map_service.dart';
import 'package:pokatuha/domain/services/service_locator.dart';
import 'package:pokatuha/domain/services/settings_service.dart';
import 'package:pokatuha/l10n/app_localizations.dart';
import 'package:pokatuha/presentation/activities/activity_detail_page.dart';
import 'package:pokatuha/presentation/app_view_model.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with AutomaticKeepAliveClientMixin {
  late Future<_MapData> _future;
  final MapController _mapController = MapController();

  /// Points of the route selected via «Show route» (drawn as a polyline).
  List<LatLng> _selectedRoutePoints = [];

  /// Live GPS sharing state (basic local version; P2P sync — S5).
  bool _sharingLocation = false;
  StreamSubscription<GpsSample>? _locationSub;

  /// 15-minute periodic fallback timer (V2 §6 — refreshes local participant
  /// positions for viewers when no FCM wake-up has triggered an update).
  Timer? _periodicFallback;

  /// Current map zoom — used to decide clustering threshold.
  double _currentZoom = 12;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _periodicFallback?.cancel();
    serviceLocator<GpsService>().stopSharing();
    super.dispose();
  }

  void _load() {
    _future = () async {
      final events = await serviceLocator<EventRepository>().all();
      final participants = serviceLocator<ParticipantRepository>();
      final liveEvents = <EventCollection>[];
      final liveParticipants = <_LiveParticipant>[];
      for (final e in events) {
        if (e.meetingPoint != null) liveEvents.add(e);
        if (e.status == EventStatus.ride.name) {
          // V2 §11 — each live participant is ringed with its activity color.
          final accent =
              Color(e.accentColor ?? EventCollection.defaultAccentColorArgb);
          for (final p in await participants.byEvent(e.id)) {
            liveParticipants
                .add(_LiveParticipant(participant: p, accent: accent));
          }
        }
      }
      return _MapData(events: liveEvents, participants: liveParticipants);
    }();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      body: FutureBuilder<_MapData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          final center = _initialCenter(data);
          return FlutterMap(
            key: ValueKey('map-${serviceLocator<MapService>().provider.name}'),
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: _currentZoom,
              minZoom: 3,
              maxZoom: 19,
              onPositionChanged: (position, hasGesture) {
                final z = position.zoom;
                if (z != _currentZoom) {
                  setState(() => _currentZoom = z);
                }
              },
            ),
            children: [
              serviceLocator<MapService>().tileLayer(),
              if (_selectedRoutePoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _selectedRoutePoints,
                      strokeWidth: 4,
                      color: DesignTokens.primary,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  ...data.events.map(_meetingMarker),
                  ..._participantMarkers(data.participants),
                ],
              ),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors',
                      onTap: () {}),
                ],
              ),
            ],
          );
        },
      ),
      appBar: AppBar(title: Text(l.tabMap), actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () => setState(_load),
        ),
      ]),
      // V2 map action menu (MAPS_AND_GPS_FIX.md §5).
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showActionSheet(context),
        child: const Icon(Icons.menu_rounded),
      ),
    );
  }

  LatLng _initialCenter(_MapData data) {
    for (final e in data.events) {
      if (e.meetingPoint != null) {
        return LatLng(e.meetingPoint!.lat, e.meetingPoint!.lng);
      }
    }
    for (final lp in data.participants) {
      final p = lp.participant;
      if (p.lastLat != null) return LatLng(p.lastLat!, p.lastLng!);
    }
    return const LatLng(0, 0);
  }

  Marker _meetingMarker(EventCollection e) {
    final gp = e.meetingPoint!;
    return Marker(
      point: LatLng(gp.lat, gp.lng),
      width: 48,
      height: 48,
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ActivityDetailPage(eventId: e.id))),
        child: const Icon(Icons.place_rounded, color: Colors.red, size: 36),
      ),
    );
  }

  // --- Participant markers (V2 §4, §6 + S4-T4 + S4-T6) ---

  /// Build participant markers, clustering overlapping ones when zoomed out
  /// (V2 §6 — cluster overlapping participant icons when zoomed out).
  List<Marker> _participantMarkers(List<_LiveParticipant> participants) {
    final withPosition = participants
        .where((lp) => lp.participant.lastLat != null)
        .toList();
    if (withPosition.isEmpty) return [];

    // Below zoom 14 (~city-level), cluster markers within ~1 km into a single
    // count badge so the map stays readable. Above 14, render individually.
    if (_currentZoom >= 14) {
      return withPosition.map(_singleParticipantMarker).toList();
    }
    final clusters = _clusterParticipants(withPosition, thresholdMeters: 1000);
    return clusters.map(_clusterMarker).toList();
  }

  /// V2 §4 — single participant marker: circular avatar ringed with the
  /// activity accent color + heading arrow (rotated by bearing) + speed
  /// badge. Tapping opens the participant popup sheet (S4-T5).
  Marker _singleParticipantMarker(_LiveParticipant lp) {
    final p = lp.participant;
    return Marker(
      point: LatLng(p.lastLat!, p.lastLng!),
      width: 52,
      height: 60,
      child: GestureDetector(
        onTap: () => _showParticipantPopup(lp),
        child: _ParticipantAvatar(
          accent: lp.accent,
          heading: p.lastHeading,
          speed: p.lastSpeed,
        ),
      ),
    );
  }

  /// Cluster marker — single pill showing the count of overlapping
  /// participants.
  Marker _clusterMarker(_ParticipantCluster cluster) {
    return Marker(
      point: cluster.center,
      width: 56,
      height: 56,
      child: GestureDetector(
        onTap: () {
          _mapController.move(cluster.center, 16);
        },
        child: Container(
          decoration: BoxDecoration(
            color: cluster.accent,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              '${cluster.count}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Distance-based clustering (simple, no external dependency). Returns
  /// clusters where each member is within [thresholdMeters] of the cluster
  /// centroid.
  List<_ParticipantCluster> _clusterParticipants(
    List<_LiveParticipant> participants, {
    required double thresholdMeters,
  }) {
    final remaining = [...participants];
    final clusters = <_ParticipantCluster>[];
    while (remaining.isNotEmpty) {
      final seed = remaining.removeLast();
      var cx = seed.participant.lastLat!;
      var cy = seed.participant.lastLng!;
      var n = 1;
      var accent = seed.accent;
      final members = <_LiveParticipant>[seed];
      for (var i = remaining.length - 1; i >= 0; i--) {
        final m = remaining[i];
        final d = GeoUtils.distanceMeters(
          lat1: m.participant.lastLat!,
          lng1: m.participant.lastLng!,
          lat2: cx / n,
          lng2: cy / n,
        );
        if (d <= thresholdMeters) {
          members.add(m);
          cx += m.participant.lastLat!;
          cy += m.participant.lastLng!;
          n += 1;
          remaining.removeAt(i);
        }
      }
      final lat = cx / n;
      final lng = cy / n;
      clusters.add(_ParticipantCluster(
        center: LatLng(lat, lng),
        count: n,
        accent: accent,
        members: members,
      ));
    }
    return clusters;
  }

  // --- Map action menu (MAPS_AND_GPS_FIX.md §5) ---

  void _showActionSheet(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(DesignTokens.space4),
              child: Text(l.mapActions,
                  style: Theme.of(sheetContext).textTheme.titleMedium),
            ),
            ListTile(
              leading: const Icon(Icons.my_location_rounded),
              title: Text(l.findMe),
              onTap: () {
                Navigator.pop(sheetContext);
                _findMe();
              },
            ),
            ListTile(
              leading: Icon(
                _sharingLocation
                    ? Icons.location_off_rounded
                    : Icons.location_searching_rounded,
              ),
              title: Text(
                  _sharingLocation ? l.stopSharingLocation : l.shareLocation),
              onTap: () {
                Navigator.pop(sheetContext);
                _toggleShareLocation();
              },
            ),
            ListTile(
              leading: const Icon(Icons.route_rounded),
              title: Text(l.showRoute),
              onTap: () {
                Navigator.pop(sheetContext);
                _showRoutePicker();
              },
            ),
            ListTile(
              leading: const Icon(Icons.download_rounded),
              title: Text(l.downloadGpx),
              onTap: () {
                Navigator.pop(sheetContext);
                _downloadGpx();
              },
            ),
            ListTile(
              leading: const Icon(Icons.map_outlined),
              title: Text(l.selectMap),
              onTap: () {
                Navigator.pop(sheetContext);
                _showLayerSwitcher();
              },
            ),
            ListTile(
              leading: const Icon(Icons.people_outline_rounded),
              title: Text(l.showParticipants),
              onTap: () {
                Navigator.pop(sheetContext);
                _showParticipantsList();
              },
            ),
            const SizedBox(height: DesignTokens.space2),
          ],
        ),
      ),
    );
  }

  /// «Найти меня» — center on the current GPS position.
  Future<void> _findMe() async {
    try {
      final sample = await serviceLocator<GpsService>().current();
      _mapController.move(LatLng(sample.lat, sample.lng), 15);
    } on AppError catch (e) {
      _toast(e.message);
    }
  }

  /// «Поделиться местоположением» — stream GPS into my participant records
  /// of active (ride) activities. Basic local version: positions are stored
  /// locally and rendered on the map. V2 §3 starts an Android foreground
  /// service (S4-T8) so the stream keeps flowing when the app is in the
  /// background. V2 §6 also requires a 15-minute periodic fallback timer
  /// (S4-T9) — wired here.
  Future<void> _toggleShareLocation() async {
    final l = AppLocalizations.of(context)!;
    final fg = serviceLocator<ForegroundLocationService>();
    if (_sharingLocation) {
      _locationSub?.cancel();
      _locationSub = null;
      _periodicFallback?.cancel();
      _periodicFallback = null;
      serviceLocator<GpsService>().stopSharing();
      await fg.stop();
      setState(() => _sharingLocation = false);
      _toast(l.locationSharingOff);
      return;
    }
    final me = context.read<AppViewModel>().user;
    if (me == null) return;
    try {
      if (!await serviceLocator<GpsService>().ensurePermission()) {
        _toast(l.gpsPermissionDenied);
        return;
      }
      final events = serviceLocator<EventRepository>();
      final participants = serviceLocator<ParticipantRepository>();
      final liveEvents = await events.byStatus(EventStatus.ride);
      final mine = <ParticipantCollection>[];
      for (final e in liveEvents) {
        final p = await participants.byEventAndUser(e.id, me.id);
        if (p != null) mine.add(p);
      }
      if (mine.isEmpty) {
        _toast(l.noActiveActivity);
        return;
      }
      await fg.start(
        title: l.gpsForegroundTracking,
        body: l.gpsForegroundTrackingBody,
      );
      final stream = serviceLocator<GpsService>().startSharing();
      _locationSub = stream.listen((sample) async {
        for (final p in mine) {
          await participants.updateLivePosition(
            p,
            lat: sample.lat,
            lng: sample.lng,
            speed: sample.speed,
            heading: sample.heading,
          );
        }
        if (mounted) setState(_load);
      });
      // V2 §6 — 15-minute periodic fallback. Re-emits the last sample to
      // participant records so map timestamps stay fresh for viewers when
      // no movement has happened.
      _periodicFallback =
          Timer.periodic(const Duration(minutes: 15), (_) async {
        if (!mounted || !_sharingLocation) return;
        for (final p in mine) {
          await participants.touchLastSeen(p);
        }
      });
      setState(() => _sharingLocation = true);
      _toast(l.locationSharingOn);
    } on AppError catch (e) {
      _toast(e.message);
    }
  }

  /// «Показать маршрут» — pick an activity with a route, fit its bounds and
  /// draw the polyline.
  Future<void> _showRoutePicker() async {
    final l = AppLocalizations.of(context)!;
    final routes = await _routesWithEvents();
    if (!mounted) return;
    if (routes.isEmpty) {
      _showEmptySheet(title: l.noRoutes, subtitle: l.noRoutesHint);
      return;
    }
    final selected = await _showPickerSheet<_RoutePick>(
      title: l.showRoute,
      items: routes,
      label: (r) => '${r.event.title} — ${r.route.name}',
    );
    if (selected == null) return;
    final points =
        selected.route.waypoints.map((w) => LatLng(w.lat, w.lng)).toList();
    setState(() => _selectedRoutePoints = points);
    if (points.length >= 2) {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.all(48),
        ),
      );
    } else if (points.isNotEmpty) {
      _mapController.move(points.first, 13);
    }
  }

  /// «Скачать GPX» — pick a route, export as .gpx and share
  /// (MAPS_AND_GPS_FIX.md §5, FR-008).
  Future<void> _downloadGpx() async {
    final l = AppLocalizations.of(context)!;
    final routes = await _routesWithEvents();
    if (!mounted) return;
    if (routes.isEmpty) {
      _showEmptySheet(title: l.noRoutes, subtitle: l.noRoutesHint);
      return;
    }
    final selected = await _showPickerSheet<_RoutePick>(
      title: l.downloadGpx,
      items: routes,
      label: (r) => '${r.event.title} — ${r.route.name}',
    );
    if (selected == null) return;
    try {
      final gpx = serviceLocator<GpxService>().build(
        name: selected.route.name,
        points: selected.route.waypoints,
      );
      final dir = await getTemporaryDirectory();
      final safeName =
          selected.route.name.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final file = File('${dir.path}/$safeName.gpx');
      await file.writeAsString(gpx);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: selected.route.name,
      );
      _toast(l.gpxExported);
    } on AppError catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast(l.downloadGpx);
    }
  }

  /// «Выбрать карту» — V2 layer switcher (S4-T3). Offers all five V2
  /// providers with localized labels; selection is persisted via
  /// SettingsService (MAPS_AND_GPS_FIX.md §6).
  Future<void> _showLayerSwitcher() async {
    final l = AppLocalizations.of(context)!;
    final mapService = serviceLocator<MapService>();
    final providers = MapService.v2Providers;
    final selected = await showModalBottomSheet<MapProvider>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(DesignTokens.space4),
              child: Text(l.selectMap,
                  style: Theme.of(sheetContext).textTheme.titleMedium),
            ),
            ...providers.map(
              (p) => RadioListTile<MapProvider>(
                value: p,
                groupValue: mapService.provider,
                onChanged: (v) => Navigator.pop(sheetContext, v),
                title: Text(_providerLabel(l, p)),
                subtitle: Text(_providerContextHint(l, p)),
              ),
            ),
            const SizedBox(height: DesignTokens.space2),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    mapService.setProvider(selected);
    final vm = context.read<AppViewModel>();
    final settings = vm.settings;
    if (settings != null) {
      await vm.updateSettings(
        await serviceLocator<SettingsService>()
            .setMapProvider(settings, selected),
      );
    }
    setState(_load);
  }

  String _providerLabel(AppLocalizations l, MapProvider p) {
    switch (p) {
      case MapProvider.openStreetMap:
        return l.openStreetMap;
      case MapProvider.cyclOSM:
        return l.cyclOSM;
      case MapProvider.openTopoMap:
        return l.openTopoMap;
      case MapProvider.esriSatellite:
        return l.esriSatellite;
      case MapProvider.cartoVoyager:
        return l.cartoVoyager;
      case MapProvider.mapLibre:
        return l.mapLibre;
      case MapProvider.googleMaps:
        return l.googleMaps;
      case MapProvider.here:
        return l.hereMaps;
      case MapProvider.twoGis:
        return l.twoGis;
      case MapProvider.yandexMaps:
        return l.yandexMaps;
    }
  }

  /// V2 §1 — context hint under each radio in the layer switcher.
  String _providerContextHint(AppLocalizations l, MapProvider p) {
    switch (p) {
      case MapProvider.cyclOSM:
        return l.mapLayerByContext(l.mapContextCycling);
      case MapProvider.openTopoMap:
        return l.mapLayerByContext(l.mapContextMountains);
      case MapProvider.esriSatellite:
        return l.mapLayerByContext(l.mapContextForest);
      case MapProvider.cartoVoyager:
        return l.mapLayerByContext(l.mapContextCity);
      case MapProvider.openStreetMap:
      case MapProvider.mapLibre:
      case MapProvider.googleMaps:
      case MapProvider.here:
      case MapProvider.twoGis:
      case MapProvider.yandexMaps:
        return '';
    }
  }

  /// «Показать участников» — list participants of active activities with a
  /// live position; tap to center the map.
  Future<void> _showParticipantsList() async {
    final l = AppLocalizations.of(context)!;
    final participants = serviceLocator<ParticipantRepository>();
    final events = serviceLocator<EventRepository>();
    final users = serviceLocator<UserRepository>();
    final liveEvents = await events.byStatus(EventStatus.ride);
    final items = <_ParticipantPick>[];
    for (final e in liveEvents) {
      for (final p in await participants.byEvent(e.id)) {
        if (p.lastLat == null || p.lastLng == null) continue;
        final user = await users.getById(p.userId);
        items.add(_ParticipantPick(
          name: user?.displayName ?? p.userId.substring(0, 6),
          eventTitle: e.title,
          lat: p.lastLat!,
          lng: p.lastLng!,
        ));
      }
    }
    if (!mounted || items.isEmpty) {
      _showEmptySheet(
          title: l.noParticipantsOnMap, subtitle: l.noActiveActivity);
      return;
    }
    final selected = await _showPickerSheet<_ParticipantPick>(
      title: l.showParticipants,
      items: items,
      label: (p) => '${p.name} · ${p.eventTitle}',
    );
    if (selected == null) return;
    _mapController.move(LatLng(selected.lat, selected.lng), 15);
  }

  /// V2 §4 — S4-T5 — participant popup sheet on marker tap. Shows name,
  /// status text, speed (km/h), distance to me, heading text, battery %.
  Future<void> _showParticipantPopup(_LiveParticipant lp) async {
    final l = AppLocalizations.of(context)!;
    final p = lp.participant;
    final users = serviceLocator<UserRepository>();
    final user = await users.getById(p.userId);
    final name = user?.displayName ?? p.userId.substring(0, 6);
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final speedKmh = p.lastSpeed != null
            ? (p.lastSpeed! * 3.6).toStringAsFixed(1)
            : null;
        final batteryPct = p.lastBattery;
        final headingText = p.lastHeading != null
            ? _headingText(l, p.lastHeading!)
            : null;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(DesignTokens.space5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _ParticipantAvatar(
                      accent: lp.accent,
                      heading: p.lastHeading,
                      speed: p.lastSpeed,
                      size: 48,
                    ),
                    const SizedBox(width: DesignTokens.space4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: theme.textTheme.titleMedium),
                          Text(_statusLabel(l, p),
                              style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DesignTokens.space4),
                _PopupRow(label: l.mapParticipantSpeed,
                    value: speedKmh != null
                        ? l.mapParticipantSpeedValue(speedKmh)
                        : '—'),
                if (headingText != null)
                  _PopupRow(
                      label: l.mapParticipantHeading, value: headingText),
                if (batteryPct != null)
                  _PopupRow(
                    label: l.mapParticipantBattery,
                    value: l.mapParticipantBatteryValue(batteryPct),
                  ),
                const SizedBox(height: DesignTokens.space3),
              ],
            ),
          ),
        );
      },
    );
  }

  String _statusLabel(AppLocalizations l, ParticipantCollection p) {
    if (p.arrivalStage == 'arrived') return l.mapParticipantStatusArrived;
    if (p.status == ParticipantStatus.accepted.name ||
        p.status == ParticipantStatus.invited.name) {
      return l.mapParticipantStatusRiding;
    }
    return l.mapParticipantStatusIdle;
  }

  /// Map a bearing (degrees 0..360) to a localized compass-direction text.
  String _headingText(AppLocalizations l, double bearing) {
    final b = (bearing + 360) % 360;
    if (b >= 337.5 || b < 22.5) return l.mapHeadingN;
    if (b < 67.5) return l.mapHeadingNE;
    if (b < 112.5) return l.mapHeadingE;
    if (b < 157.5) return l.mapHeadingSE;
    if (b < 202.5) return l.mapHeadingS;
    if (b < 247.5) return l.mapHeadingSW;
    if (b < 292.5) return l.mapHeadingW;
    return l.mapHeadingNW;
  }

  // --- helpers ---

  Future<List<_RoutePick>> _routesWithEvents() async {
    final events = await serviceLocator<EventRepository>().all();
    final routes = serviceLocator<RouteRepository>();
    final picks = <_RoutePick>[];
    for (final e in events) {
      for (final r in await routes.byEvent(e.id)) {
        picks.add(_RoutePick(event: e, route: r));
      }
    }
    return picks;
  }

  Future<T?> _showPickerSheet<T>({
    required String title,
    required List<T> items,
    required String Function(T) label,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(DesignTokens.space4),
              child: Text(title,
                  style: Theme.of(sheetContext).textTheme.titleMedium),
            ),
            ...items.map(
              (item) => ListTile(
                leading: const Icon(Icons.chevron_right_rounded),
                title: Text(label(item)),
                onTap: () => Navigator.pop(sheetContext, item),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEmptySheet({required String title, required String subtitle}) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 40, color: Theme.of(sheetContext).colorScheme.outline),
              const SizedBox(height: DesignTokens.space3),
              Text(title, style: Theme.of(sheetContext).textTheme.titleMedium),
              const SizedBox(height: DesignTokens.space2),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(sheetContext).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _MapData {
  _MapData({required this.events, required this.participants});

  final List<EventCollection> events;
  final List<_LiveParticipant> participants;
}

/// A live participant together with its activity accent color (V2 §11).
class _LiveParticipant {
  _LiveParticipant({required this.participant, required this.accent});

  final ParticipantCollection participant;
  final Color accent;
}

class _RoutePick {
  _RoutePick({required this.event, required this.route});

  final EventCollection event;
  final RouteCollection route;
}

class _ParticipantPick {
  _ParticipantPick({
    required this.name,
    required this.eventTitle,
    required this.lat,
    required this.lng,
  });

  final String name;
  final String eventTitle;
  final double lat;
  final double lng;
}

/// Cluster of overlapping participants (V2 §6).
class _ParticipantCluster {
  _ParticipantCluster({
    required this.center,
    required this.count,
    required this.accent,
    required this.members,
  });

  final LatLng center;
  final int count;
  final Color accent;
  final List<_LiveParticipant> members;
}

/// V2 §4 — circular avatar ringed with the activity accent color, with a
/// heading arrow rotated by bearing and a speed badge.
class _ParticipantAvatar extends StatelessWidget {
  const _ParticipantAvatar({
    required this.accent,
    this.heading,
    this.speed,
    this.size = 44,
  });

  final Color accent;
  final double? heading;
  final double? speed; // m/s
  final double size;

  @override
  Widget build(BuildContext context) {
    final speedKmh = (speed != null && speed! > 0)
        ? (speed! * 3.6).round().toString()
        : null;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Outer ring — activity accent color (V2 §11).
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: const Icon(
              Icons.directions_bike_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          // Heading arrow — a small triangle rotated by bearing, anchored
          // on the outer ring (V2 §4 — heading arrow).
          if (heading != null && heading! >= 0)
            Positioned(
              left: size / 2 - 6,
              top: -8,
              child: Transform.rotate(
                angle: heading! * math.pi / 180.0,
                child: const CustomPaint(
                  size: Size(12, 12),
                  painter: _HeadingArrowPainter(),
                ),
              ),
            ),
          // Speed badge — bottom-right.
          if (speedKmh != null)
            Positioned(
              right: -4,
              bottom: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accent, width: 1),
                ),
                child: Text(
                  speedKmh,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeadingArrowPainter extends CustomPainter {
  const _HeadingArrowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width / 2, size.height * 0.7)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
    final border = Paint()
      ..color = const Color(0xFF1A1A2E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawPath(path, border);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// V2 §4 — a single label : value row in the participant popup sheet.
class _PopupRow extends StatelessWidget {
  const _PopupRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DesignTokens.space1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(value,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
