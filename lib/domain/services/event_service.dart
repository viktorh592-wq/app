/// Event service — orchestrates activity lifecycle enforcing business rules
/// (BR-001..BR-010) and the activity timeline (BR-010).
import 'dart:convert';

import 'package:pokatuha/core/errors/app_error.dart';
import 'package:pokatuha/database/collections/embedded/geo_point.dart';
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

  /// Create a new activity (UC-001) inside a group — V2 Group-first model
  /// (GROUPS_AND_ACTIVITIES.md §1: users never create standalone activities
  /// from the main screen). The organizer is auto-added as a participant
  /// (BR-001 — every activity belongs to exactly one organizer).
  ///
  /// [accentColor] — activity accent (ARGB); defaults to violet
  /// (EventCollection.defaultAccentColorArgb) per V2 §10, §11.
  Future<EventCollection> createActivity({
    required UserCollection organizer,
    required String groupId,
    required String title,
    required String description,
    required int startAt,
    required String activityTypeId,
    double? meetingLat,
    double? meetingLng,
    String? meetingPointLabel,
    EventVisibility visibility = EventVisibility.private,
    int? maxParticipants,
    int? accentColor,
  }) async {
    final event = EventCollection()
      ..groupId = groupId
      ..title = title
      ..description = description
      ..startAt = startAt
      ..activityTypeId = activityTypeId
      ..organizerId = organizer.id
      ..visibility = visibility.name
      ..maxParticipants = maxParticipants
      ..accentColor = accentColor ?? EventCollection.defaultAccentColorArgb
      ..meetingPointLabel = meetingPointLabel
      ..arrivalThresholdNear = 500
      ..arrivalThresholdClose = 200
      ..arrivalThresholdArrived = 50
      ..createdBy = organizer.id;
    if (meetingLat != null && meetingLng != null) {
      event.meetingPoint = GeoPoint(lat: meetingLat, lng: meetingLng);
    }

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

  /// Edit an existing activity (V2 §9 — activity menu → Edit). Validates the
  /// same invariants as creation (title, start time).
  Future<EventCollection> editActivity({
    required EventCollection event,
    required String title,
    required String description,
    required int startAt,
    required String activityTypeId,
    double? meetingLat,
    double? meetingLng,
    String? meetingPointLabel,
    EventVisibility? visibility,
    int? maxParticipants,
    int? accentColor,
  }) async {
    if (title.trim().isEmpty) {
      throw const BusinessRuleError('Event title is required');
    }
    if (startAt <= 0) {
      throw const BusinessRuleError('Event start time is required');
    }
    event
      ..title = title
      ..description = description
      ..startAt = startAt
      ..activityTypeId = activityTypeId
      ..meetingPointLabel = meetingPointLabel
      ..visibility = (visibility ?? EventVisibility.private).name
      ..maxParticipants = maxParticipants
      ..accentColor = accentColor ?? event.accentColor;
    if (meetingLat != null && meetingLng != null) {
      event.meetingPoint = GeoPoint(lat: meetingLat, lng: meetingLng);
    }
    final updated = await _eventRepository.update(event);
    _addTimeline(
        event.id,
        TimelineEntry(
          timestamp: updated.updatedAt,
          action: 'ride_updated',
          detail: updated.title,
        ));
    return updated;
  }

  /// Duplicate an activity (V2 §9 — activity menu → Duplicate): creates a
  /// fresh copy in the same group in `preparation` with the same route
  /// parameters and accent color. Legacy activities without a group cannot
  /// be duplicated (V2 Group-first model).
  Future<EventCollection> duplicate({
    required EventCollection event,
    required UserCollection organizer,
  }) async {
    final groupId = event.groupId;
    if (groupId == null || groupId.isEmpty) {
      throw const BusinessRuleError(
          'Cannot duplicate a legacy activity without a group');
    }
    final visibility = EventVisibility.values.firstWhere(
      (v) => v.name == event.visibility,
      orElse: () => EventVisibility.private,
    );
    final copy = await createActivity(
      organizer: organizer,
      groupId: groupId,
      title: '${event.title} (copy)',
      description: event.description,
      startAt: event.startAt,
      activityTypeId: event.activityTypeId,
      meetingLat: event.meetingPoint?.lat,
      meetingLng: event.meetingPoint?.lng,
      meetingPointLabel: event.meetingPointLabel,
      visibility: visibility,
      maxParticipants: event.maxParticipants,
      accentColor: event.accentColor,
    );
    _addTimeline(
        event.id,
        TimelineEntry(
          timestamp: copy.createdAt,
          action: 'ride_duplicated',
          detail: copy.id,
          actorId: organizer.id,
        ));
    return copy;
  }

  /// Pin / unpin the activity in its group (V2 §9 — activity menu → Pin).
  Future<EventCollection> setPinned(EventCollection event, bool pinned) async {
    event.pinnedInGroup = pinned;
    final updated = await _eventRepository.update(event);
    _addTimeline(
        event.id,
        TimelineEntry(
          timestamp: updated.updatedAt,
          action: pinned ? 'activity_pinned' : 'activity_unpinned',
        ));
    return updated;
  }

  /// Archive an activity immediately (V2 §9 — activity menu → Archive).
  /// Behaves like [finishRide] but may be called from any non-archived
  /// status; creates the archive record (BR-007) and stops GPS sharing.
  Future<void> archiveNow(EventCollection event) async {
    if (event.status == EventStatus.archived.name) {
      throw const BusinessRuleError('Activity is already archived');
    }
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
        event.id, TimelineEntry(timestamp: now, action: 'ride_archived'));
  }

  /// Soft-delete an activity (V2 §9 — activity menu → Delete,
  /// Soft_Delete.md). The archive record is kept (BR-007).
  Future<void> deleteActivity(EventCollection event, {String? by}) async {
    await _eventRepository.softDelete(event, by: by);
    _addTimeline(
        event.id, TimelineEntry(timestamp: _now(), action: 'ride_deleted'));
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
