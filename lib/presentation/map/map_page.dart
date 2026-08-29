/// Map tab — OpenStreetMap / MapLibre via flutter_map (Maps rules). Shows
/// activity meeting points and live participant positions (FR-005).
/// FAB opens the map action menu with the six V2 actions
/// (MAPS_AND_GPS_FIX.md §5): find me, share location, show route,
/// download GPX, select map, show participants.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:pokatuha/core/errors/app_error.dart';
import 'package:pokatuha/core/tokens/design_tokens.dart';
import 'package:pokatuha/database/collections/event_collection.dart';
import 'package:pokatuha/database/collections/participant_collection.dart';
import 'package:pokatuha/database/collections/route_collection.dart';
import 'package:pokatuha/domain/enums/enums.dart';
import 'package:pokatuha/domain/repositories/event_repository.dart';
import 'package:pokatuha/domain/repositories/participant_repository.dart';
import 'package:pokatuha/domain/repositories/route_repository.dart';
import 'package:pokatuha/domain/repositories/user_repository.dart';
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

  /// Live GPS sharing state (basic local version; P2P sync — S4-T3).
  bool _sharingLocation = false;
  StreamSubscription<GpsSample>? _locationSub;

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
              initialZoom: 12,
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
                  ...data.participants
                      .where((lp) => lp.participant.lastLat != null)
                      .map(_participantMarker),
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

  /// Live participant marker with an activity-accent ring (V2 §4, §11 —
  /// MAPS_AND_GPS_FIX.md participant marker, FIX_PLAN S2-T7).
  Marker _participantMarker(_LiveParticipant lp) {
    final p = lp.participant;
    return Marker(
      point: LatLng(p.lastLat!, p.lastLng!),
      width: 44,
      height: 44,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: lp.accent,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: const Icon(
          Icons.directions_bike_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
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
  /// locally and rendered on the map; P2P propagation arrives with S4-T3.
  Future<void> _toggleShareLocation() async {
    final l = AppLocalizations.of(context)!;
    if (_sharingLocation) {
      _locationSub?.cancel();
      _locationSub = null;
      serviceLocator<GpsService>().stopSharing();
      setState(() => _sharingLocation = false);
      _toast(l.locationSharingOff);
      return;
    }
    final me = context.read<AppViewModel>().user;
    if (me == null) return;
    try {
      if (!await serviceLocator<GpsService>().ensurePermission()) {
        _toast(l.noActiveActivity);
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

  /// «Выбрать карту» — layer switcher. Sprint 1 offers the two natively
  /// rendered providers (OSM, MapLibre); the V2 provider set
  /// (CyclOSM/OpenTopoMap/Esri/Carto) arrives with S4-T1/S4-T2. The choice
  /// is persisted in local settings (MAPS_AND_GPS_FIX.md §6).
  Future<void> _showLayerSwitcher() async {
    final l = AppLocalizations.of(context)!;
    final mapService = serviceLocator<MapService>();
    final providers = const [MapProvider.openStreetMap, MapProvider.mapLibre];
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
                title: Text(p == MapProvider.openStreetMap
                    ? l.openStreetMap
                    : l.mapLibre),
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
