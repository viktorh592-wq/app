/// Event service — orchestrates activity lifecycle enforcing business rules
/// (BR-001..BR-010) and the activity timeline (BR-010).
import 'dart:convert';

import 'package:pokatuha/core/errors/app_error.dart';
import 'package:pokatuha/database/collections/event_collection.dart';
import 'package:pokatuha/database/collections/participant_collection.dart';
import 'package:pokatuha/database/collections/user_collection.dart';
import 'package:pokatuha/domain/enums/enums.dart';
import 'package:pokatuha/domain/repositories/archive_repository.dart';
import 'package:pokatuha/domain/repositories/event_repository.dart';
import 'package:pokatuha/domain/repositories/participant_repository.dart';

/// A timeline entry (BR-010 — every significant action is recorded).
class TimelineEntry {
  TimelineEntry({
    required this.timestamp,
    required this.action,
    this.detail,
    this.actorId,
  });

  final int timestamp;
  final String action;
  final String? detail;
  final String? actorId;

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp,
        'action': action,
        'detail': detail,
        'actorId': actorId,
      };
}

class EventService {
  EventService(
    this._eventRepository,
    this._participantRepository,
    this._archiveRepository,
  );

  final EventRepository _eventRepository;
  final ParticipantRepository _participantRepository;
  final ArchiveRepository _archiveRepository;

  final List<TimelineEntry> _timelines = <TimelineEntry>[];

  /// Create a new activity (UC-001). The organizer is auto-added as a
  /// participant (BR-001 — every activity belongs to exactly one organizer).
  Future<EventCollection> createActivity({
    required UserCollection organizer,
    required String title,
    required String description,
    required int startAt,
    required String activityTypeId,
    required double meetingLat,
    required double meetingLng,
    String? meetingPointLabel,
    EventVisibility visibility = EventVisibility.private,
    int? maxParticipants,
  }) async {
    final event = EventCollection()
      ..title = title
      ..description = description
      ..startAt = startAt
      ..activityTypeId = activityTypeId
      ..organizerId = organizer.id
      ..visibility = visibility.name
      ..maxParticipants = maxParticipants
      ..meetingPointLabel = meetingPointLabel
      ..arrivalThresholdNear = 500
      ..arrivalThresholdClose = 200
      ..arrivalThresholdArrived = 50
      ..createdBy = organizer.id;

    final created = await _eventRepository.create(event);

    // Organizer auto-joins as accepted organizer (BR-001, FR-003).
    await _participantRepository.invite(
      eventId: created.id,
      userId: organizer.id,
      role: ParticipantRole.organizer.name,
      byUserId: organizer.id,
    );
    final organizerP = await _participantRepository.byEventAndUser(
      created.id,
      organizer.id,
    );
    if (organizerP != null) {
      await _participantRepository.setStatus(
        organizerP,
        ParticipantStatus.accepted,
      );
    }

    _addTimeline(
        created.id,
        TimelineEntry(
          timestamp: created.createdAt,
          action: 'ride_created',
          detail: created.title,
          actorId: organizer.id,
        ));

    return created;
  }

  /// Join an activity (UC-002).
  Future<ParticipantCollection> join({
    required EventCollection event,
    required UserCollection user,
  }) async {
    if (event.status == EventStatus.archived.name) {
      throw const BusinessRuleError(
          'Cannot join an archived activity (BR-002)');
    }
    if (event.maxParticipants != null) {
      final accepted = await _participantRepository.acceptedCount(event.id);
      if (accepted >= event.maxParticipants!) {
        throw const BusinessRuleError('Activity is full');
      }
    }
    var participant =
        await _participantRepository.byEventAndUser(event.id, user.id);
    participant ??= await _participantRepository.invite(
      eventId: event.id,
      userId: user.id,
      byUserId: user.id,
    );
    final updated = await _participantRepository.setStatus(
      participant,
      ParticipantStatus.accepted,
    );
    _addTimeline(
        event.id,
        TimelineEntry(
          timestamp: updated.updatedAt,
          action: 'participant_joined',
          actorId: user.id,
        ));
    return updated;
  }

  /// Leave an activity (BR-009 — users may leave at any time).
  Future<ParticipantCollection> leave({
    required EventCollection event,
    required UserCollection user,
  }) async {
    final participant =
        await _participantRepository.byEventAndUser(event.id, user.id);
    if (participant == null) {
      throw const NotFoundError('Not a participant');
    }
    final updated = await _participantRepository.setStatus(
      participant,
      ParticipantStatus.left,
    );
    _addTimeline(
        event.id,
        TimelineEntry(
          timestamp: updated.updatedAt,
          action: 'participant_left',
          actorId: user.id,
        ));
    return updated;
  }

  /// Start a ride (UC-003). GPS sharing begins only after explicit user
  /// confirmation (BR-005).
  Future<EventCollection> startRide(EventCollection event) async {
    if (event.status == EventStatus.archived.name) {
      throw const BusinessRuleError('Archived activity cannot start (BR-002)');
    }
    final now = _now();
    event
      ..status = EventStatus.ride.name
      ..rideStartedAt = now
      ..gpsSharingEnabled = true;
    final updated = await _eventRepository.update(event);
    _addTimeline(
        event.id,
        TimelineEntry(
          timestamp: now,
          action: 'ride_started',
        ));
    return updated;
  }

  /// Finish a ride (UC-004) — archive is created, notifications sent.
  Future<void> finishRide(EventCollection event) async {
    final now = _now();
    final startedAt = event.rideStartedAt ?? now;
    event
      ..status = EventStatus.archived.name
      ..rideFinishedAt = now
      ..gpsSharingEnabled = false;
    await _eventRepository.update(event);

    final participants = await _participantRepository.byEvent(event.id);
    final accepted = participants
        .where((p) => p.status == ParticipantStatus.accepted.name)
        .length;

    await _archiveRepository.createFromEvent(
      event,
      participantCount: accepted,
      durationSeconds: ((now - startedAt) / 1000).round(),
      timeline: timelineFor(event.id).map((e) => e.toJson()).toList(),
    );

    _addTimeline(
        event.id,
        TimelineEntry(
          timestamp: now,
          action: 'ride_finished',
        ));
  }

  void _addTimeline(String eventId, TimelineEntry entry) {
    _timelines.add(entry);
  }

  List<TimelineEntry> timelineFor(String eventId) =>
      List<TimelineEntry>.from(_timelines);

  String timelineJson(String eventId) =>
      jsonEncode(timelineFor(eventId).map((e) => e.toJson()).toList());

  int _now() => DateTime.now().toUtc().millisecondsSinceEpoch;
}
