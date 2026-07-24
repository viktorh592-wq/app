/// Archive repository (FR-009). Completed activities move automatically to
/// the archive (UC-004). An archived activity cannot become active again
/// (BR-002). Archived rides are never soft-deleted automatically
/// (Soft_Delete.md).
import 'dart:convert';

import 'package:sembast/sembast.dart';

import 'package:pokatuha/core/utils/timestamps.dart';
import 'package:pokatuha/core/utils/uuid.dart';
import 'package:pokatuha/database/collections/archive_collection.dart';
import 'package:pokatuha/database/collections/event_collection.dart';
import 'package:pokatuha/database/database.dart';

class ArchiveRepository {
  ArchiveRepository(this._db);
  final DatabaseService _db;

  TypedStore<ArchiveCollection> get _store => _db.archivesStore;

  Future<List<ArchiveCollection>> all() async => _store.find(
        filter: Filter.equals('isDeleted', false),
        sortOrders: [SortOrder('rideFinishedAt', false)],
      );

  Future<ArchiveCollection?> getByEventId(String eventId) async {
    final list = await _store.find(
      filter: Filter.equals('eventId', eventId),
      limit: 1,
    );
    return list.isEmpty ? null : list.first;
  }

  /// Create an archive entry from a completed event (UC-004).
  /// Changing activity type does not affect archived data (BR-008).
  Future<ArchiveCollection> createFromEvent(
    EventCollection event, {
    int participantCount = 0,
    double distanceMeters = 0,
    int durationSeconds = 0,
    double elevationGainMeters = 0,
    double averageSpeed = 0,
    String? gpxFilePath,
    String? statisticsId,
    List<Map<String, dynamic>> timeline = const [],
    List<String> mediaIds = const [],
  }) async {
    final existing = await getByEventId(event.id);
    if (existing != null) {
      return existing;
    }
    final now = Timestamps.nowUtc();
    final archive = ArchiveCollection()
      ..id = UuidGenerator.generate()
      ..createdAt = now
      ..updatedAt = now
      ..version = 1
      ..isDeleted = false
      ..eventId = event.id
      ..title = event.title
      ..activityTypeId = event.activityTypeId
      ..rideStartedAt = event.rideStartedAt ?? 0
      ..rideFinishedAt = event.rideFinishedAt ?? now
      ..participantCount = participantCount
      ..distanceMeters = distanceMeters
      ..durationSeconds = durationSeconds
      ..elevationGainMeters = elevationGainMeters
      ..averageSpeed = averageSpeed
      ..gpxFilePath = gpxFilePath
      ..statisticsId = statisticsId
      ..timelineJson = timeline.isEmpty ? null : jsonEncode(timeline)
      ..mediaIdsJson = mediaIds.isEmpty ? null : jsonEncode(mediaIds);
    return _store.put(archive);
  }
}
