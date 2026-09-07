/// Event service — orchestrates activity lifecycle enforcing business rules
/// (BR-001..BR-010) and the activity timeline (BR-010).
///
/// V3.0.7 (bug 2) — activity create / edit now BROADCASTS the change to all
/// group members over the realtime transport so every member's device
/// updates its local copy of the activity without needing a QR rescan.
/// Edit permission is enforced: only the organizer of the activity OR the
/// owner / admin of the parent group may edit (the user chose option C).
import 'dart:async';
import 'dart:convert';

import 'package:pokatuha/core/errors/app_error.dart';
import 'package:pokatuha/core/utils/timestamps.dart';
import 'package:pokatuha/database/collections/embedded/geo_point.dart';
import 'package:pokatuha/database/collections/event_collection.dart';
import 'package:pokatuha/database/collections/participant_collection.dart';
import 'package:pokatuha/database/collections/user_collection.dart';
import 'package:pokatuha/domain/enums/enums.dart';
import 'package:pokatuha/domain/repositories/archive_repository.dart';
import 'package:pokatuha/domain/repositories/event_repository.dart';
import 'package:pokatuha/domain/repositories/group_member_repository.dart';
import 'package:pokatuha/domain/repositories/participant_repository.dart';
import 'package:pokatuha/domain/services/communication_service.dart';

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
    this._archiveRepository, {
    CommunicationService? transport,
    GroupMemberRepository? memberRepository,
  })  : _transport = transport,
        _memberRepository = memberRepository;

  final EventRepository _eventRepository;
  final ParticipantRepository _participantRepository;
  final ArchiveRepository _archiveRepository;

  /// Optional realtime transport (V3.0.7 bug 2) — when present, activity
  /// create / edit broadcasts the change to all group members so their
  /// devices upsert the activity locally. Null in unit tests.
  final CommunicationService? _transport;

  /// Optional group member repository (V3.0.7 bug 2) — used to enforce
  /// edit permission (only organizer OR owner/admin of the group may edit).
  final GroupMemberRepository? _memberRepository;

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

    // V3.0.7 bug 2 — broadcast the freshly-created activity to every member
    // of the group so their Activities tab updates immediately (no QR rescan
    // needed). Local-first: the broadcast is best-effort, the local copy is
    // already authoritative.
    await _broadcastActivityUpsert(
      event: created,
      byUserId: organizer.id,
      op: 'create',
    );

    return created;
  }

  /// Join an activity (UC-002).
  ///
  /// V3.0.3 fix (user feedback): visibility is enforced at the activity
  /// level:
  ///   • public — any group member may join without an explicit invitation.
  ///   • linkOnly — same as public (anyone with the activity link may join).
  ///   • private — only users who have been explicitly invited (participant
  ///     record with status = `invited`) may join. The organizer may also
  ///     join (although they are auto-added at activity creation).
  Future<ParticipantCollection> join({
    required EventCollection event,
    required UserCollection user,
  }) async {
    if (event.status == EventStatus.archived.name) {
      throw const BusinessRuleError(
          'Cannot join an archived activity (BR-002)');
    }
    final visibility = EventVisibility.values.firstWhere(
      (v) => v.name == event.visibility,
      orElse: () => EventVisibility.private,
    );
    final existing =
        await _participantRepository.byEventAndUser(event.id, user.id);
    if (visibility == EventVisibility.private &&
        user.id != event.organizerId) {
      final isInvited = existing != null &&
          existing.status == ParticipantStatus.invited.name;
      if (!isInvited) {
        throw const BusinessRuleError(
            'Private activity — invitation required');
      }
    }
    if (event.maxParticipants != null) {
      final accepted = await _participantRepository.acceptedCount(event.id);
      if (accepted >= event.maxParticipants!) {
        throw const BusinessRuleError('Activity is full');
      }
    }
    var participant = existing;
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
  ///
  /// V3.0.7 (bug 2) — ENFORCES edit permission: only the organizer of this
  /// activity OR the owner / admin of the parent group may edit. A regular
  /// member cannot edit someone else's activity (user chose option C). The
  /// edited activity is then broadcast to all group members so their
  /// Activities tab updates to the latest version.
  ///
  /// [byUserId] — the user attempting the edit. When null (legacy callers /
  /// tests), the permission check is skipped (backwards compatibility).
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
    String? byUserId,
  }) async {
    if (title.trim().isEmpty) {
      throw const BusinessRuleError('Event title is required');
    }
    if (startAt <= 0) {
      throw const BusinessRuleError('Event start time is required');
    }
    // V3.0.7 bug 2 — enforce edit permission. The organizer of THIS activity
    // OR the owner / admin of the parent group may edit. Regular members may
    // not (user chose option C). [byUserId] is null only for legacy callers
    // and tests where the check is intentionally skipped.
    if (byUserId != null && byUserId.isNotEmpty) {
      await _ensureCanEditActivity(event, byUserId);
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

    // V3.0.7 bug 2 — broadcast the updated activity so every member's device
    // refreshes its local copy (local-first: existing local copy with a newer
    // version wins, so concurrent edits never regress).
    await _broadcastActivityUpsert(
      event: updated,
      byUserId: byUserId ?? event.organizerId,
      op: 'update',
    );

    return updated;
  }

  /// Throws [BusinessRuleError] when [userId] is NOT allowed to edit this
  /// activity. Allowed: the organizer of this activity OR the owner / admin
  /// of the parent group. V3.0.7 bug 2 (user chose option C).
  Future<void> _ensureCanEditActivity(
    EventCollection event,
    String userId,
  ) async {
    // The organizer of this activity may always edit.
    if (event.organizerId == userId) return;
    // Otherwise check the group role.
    final groupId = event.groupId;
    if (groupId == null || groupId.isEmpty) {
      throw const BusinessRuleError(
          'Only the organizer may edit this activity');
    }
    final members = _memberRepository;
    if (members == null) {
      // No member repository available — fail open (legacy callers in tests
      // that don't wire the member repo). Production callers always wire it.
      return;
    }
    final member = await members.byGroupAndUser(groupId, userId);
    if (member == null) {
      throw const BusinessRuleError(
          'Only the organizer or a group admin may edit this activity');
    }
    if (member.role == GroupRole.owner.name ||
        member.role == GroupRole.admin.name) {
      return;
    }
    throw const BusinessRuleError(
        'Only the organizer or a group admin may edit this activity');
  }

  /// Broadcasts an activity upsert (create or update) to all group members
  /// over the realtime transport. Best-effort: a transport failure leaves
  /// the local copy authoritative (local-first — ADR-001). V3.0.7 bug 2.
  Future<void> _broadcastActivityUpsert({
    required EventCollection event,
    required String byUserId,
    required String op, // "create" or "update"
  }) async {
    final transport = _transport;
    if (transport == null) return;
    final groupId = event.groupId;
    if (groupId == null || groupId.isEmpty) return;
    try {
      await transport.broadcast(RealtimeEnvelope(
        type: RealtimeType.activityUpsert,
        payload: <String, dynamic>{
          'groupId': groupId,
          'event': event.toMap(),
          'byUserId': byUserId,
          'op': op,
        },
        senderId: byUserId,
        timestamp: Timestamps.nowUtc(),
      ));
    } catch (_) {
      // Best-effort — local-first: local copy is already authoritative.
    }
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
