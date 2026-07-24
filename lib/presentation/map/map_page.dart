/// Map tab — OpenStreetMap / MapLibre via flutter_map (Maps rules). Shows
/// activity meeting points and live participant positions (FR-005).
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:pokatuha/database/collections/event_collection.dart';
import 'package:pokatuha/database/collections/participant_collection.dart';
import 'package:pokatuha/domain/enums/enums.dart';
import 'package:pokatuha/domain/repositories/event_repository.dart';
import 'package:pokatuha/domain/repositories/participant_repository.dart';
import 'package:pokatuha/domain/services/map_service.dart';
import 'package:pokatuha/domain/services/service_locator.dart';
import 'package:pokatuha/l10n/app_localizations.dart';
import 'package:pokatuha/presentation/activities/activity_detail_page.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  late Future<_MapData> _future;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = () async {
      final events = await serviceLocator<EventRepository>().all();
      final participants = serviceLocator<ParticipantRepository>();
      final liveEvents = <EventCollection>[];
      final liveParticipants = <ParticipantCollection>[];
      for (final e in events) {
        if (e.meetingPoint != null) liveEvents.add(e);
        if (e.status == EventStatus.ride.name) {
          liveParticipants.addAll(await participants.byEvent(e.id));
        }
      }
      return _MapData(events: liveEvents, participants: liveParticipants);
    }();
  }

  @override
  Widget build(BuildContext context) {
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
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 12,
            ),
            children: [
              serviceLocator<MapService>().tileLayer(),
              MarkerLayer(
                markers: [
                  ...data.events.map(_meetingMarker),
                  ...data.participants.where((p) => p.lastLat != null).map(
                        (p) => Marker(
                          point: LatLng(p.lastLat!, p.lastLng!),
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.directions_bike_rounded,
                              color: Colors.blue),
                        ),
                      ),
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
    );
  }

  LatLng _initialCenter(_MapData data) {
    for (final e in data.events) {
      if (e.meetingPoint != null) {
        return LatLng(e.meetingPoint!.lat, e.meetingPoint!.lng);
      }
    }
    for (final p in data.participants) {
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
}

// Local import for the MapService used above.

class _MapData {
  _MapData({required this.events, required this.participants});

  final List<EventCollection> events;
  final List<ParticipantCollection> participants;
}
