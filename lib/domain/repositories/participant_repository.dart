/// Participant repository (FR-003). A participant belongs to an Event and a
/// User (Entity_Relationships.md).
import 'package:sembast/sembast.dart';

import 'package:pokatuha/core/utils/timestamps.dart';
import 'package:pokatuha/core/utils/uuid.dart';
import 'package:pokatuha/database/collections/participant_collection.dart';
import 'package:pokatuha/database/database.dart';
import 'package:pokatuha/domain/enums/enums.dart';

class ParticipantRepository {
  ParticipantRepository(this._db);
  final DatabaseService _db;

  TypedStore<ParticipantCollection> get _store => _db.participantsStore;

  Future<List<ParticipantCollection>> byEvent(String eventId) async =>
      _store.find(
        filter: Filter.equals('eventId', eventId) &
            Filter.equals('isDeleted', false),
        sortOrders: [SortOrder('status')],
      );

  Future<ParticipantCollection?> byEventAndUser(
    String eventId,
    String userId,
  ) async {
    final list = await _store.find(
      filter: Filter.equals('eventId', eventId) &
          Filter.equals('userId', userId) &
          Filter.equals('isDeleted', false),
      limit: 1,
    );
    return list.isEmpty ? null : list.first;
  }

  Future<int> acceptedCount(String eventId) async => _store.count(
        filter: Filter.equals('eventId', eventId) &
            Filter.equals('status', ParticipantStatus.accepted.name) &
            Filter.equals('isDeleted', false),
      );

  /// Organizer creates an invitation (FR-003).
  Future<ParticipantCollection> invite({
    required String eventId,
    required String userId,
    String role = 'member',
    String? byUserId,
  }) async {
    final now = Timestamps.nowUtc();
    final p = ParticipantCollection()
      ..id = UuidGenerator.generate()
      ..createdAt = now
      ..updatedAt = now
      ..version = 1
      ..isDeleted = false
      ..eventId = eventId
      ..userId = userId
      ..status = ParticipantStatus.invited.name
      ..role = role
      ..createdBy = byUserId;
    return _store.put(p);
  }

  Future<ParticipantCollection> setStatus(
    ParticipantCollection participant,
    ParticipantStatus status,
  ) async {
    final now = Timestamps.nowUtc();
    participant
      ..status = status.name
      ..joinedAt = status == ParticipantStatus.accepted
          ? (participant.joinedAt ?? now)
          : participant.joinedAt
      ..leftAt = status == ParticipantStatus.left ? now : participant.leftAt
      ..touch(now);
    return _store.put(participant);
  }

  /// Update live GPS position (FR-005 — Live Mode).
  Future<void> updateLivePosition(
    ParticipantCollection participant, {
    required double lat,
    required double lng,
    double? speed,
    double? heading,
    int? battery,
  }) async {
    final now = Timestamps.nowUtc();
    participant
      ..lastLat = lat
      ..lastLng = lng
      ..lastSpeed = speed ?? participant.lastSpeed
      ..lastHeading = heading ?? participant.lastHeading
      ..lastBattery = battery ?? participant.lastBattery
      ..lastSeenAt = now
      ..updatedAt = now;
    await _store.put(participant);
  }
}
