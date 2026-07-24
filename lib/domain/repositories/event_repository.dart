/// Activity / event repository (FR-001, FR-002, FR-009).
/// Enforces soft-delete filtering (Soft_Delete.md).
import 'package:sembast/sembast.dart';

import 'package:pokatuha/core/errors/app_error.dart';
import 'package:pokatuha/core/utils/timestamps.dart';
import 'package:pokatuha/core/utils/uuid.dart';
import 'package:pokatuha/core/utils/validators.dart';
import 'package:pokatuha/database/collections/event_collection.dart';
import 'package:pokatuha/database/database.dart';
import 'package:pokatuha/domain/enums/enums.dart';

class EventRepository {
  EventRepository(this._db);
  final DatabaseService _db;

  TypedStore<EventCollection> get _store => _db.eventsStore;

  Future<EventCollection?> getById(String id) async {
    final e = await _store.getById(id);
    return (e != null && !e.isDeleted) ? e : null;
  }

  /// All non-deleted events ordered by start time ascending.
  Future<List<EventCollection>> all() async => _store.find(
        filter: Filter.equals('isDeleted', false),
        sortOrders: [SortOrder('startAt')],
      );

  Future<List<EventCollection>> byStatus(EventStatus status) async =>
      _store.find(
        filter: Filter.equals('status', status.name) &
            Filter.equals('isDeleted', false),
        sortOrders: [SortOrder('startAt')],
      );

  Future<List<EventCollection>> upcoming() async {
    final now = Timestamps.nowUtc();
    return _store.find(
      filter: Filter.greaterThan('startAt', now) &
          Filter.equals('isDeleted', false),
      sortOrders: [SortOrder('startAt')],
    );
  }

  Future<List<EventCollection>> live() => byStatus(EventStatus.ride);

  Future<EventCollection> create(EventCollection event) async {
    if (!Validators.isNonEmptyTrimmed(event.title)) {
      throw const BusinessRuleError('Event title is required');
    }
    if (!Validators.isValidUtcMillis(event.startAt)) {
      throw const BusinessRuleError('Event start time is required');
    }
    if (!Validators.isValidMaxParticipants(event.maxParticipants)) {
      throw const BusinessRuleError('Max participants must be positive');
    }
    final now = Timestamps.nowUtc();
    event
      ..id = UuidGenerator.generate()
      ..createdAt = now
      ..updatedAt = now
      ..version = 1
      ..isDeleted = false
      ..status =
          event.status.isEmpty ? EventStatus.preparation.name : event.status
      ..visibility = event.visibility.isEmpty
          ? EventVisibility.private.name
          : event.visibility;
    return _store.put(event);
  }

  Future<EventCollection> update(EventCollection event) async {
    event.touch(Timestamps.nowUtc());
    return _store.put(event);
  }

  /// Soft delete (Soft_Delete.md). Never deletes another activity's
  /// archive (BR-007).
  Future<void> softDelete(EventCollection event, {String? by}) async {
    event.softDelete(Timestamps.nowUtc(), by: by);
    await _store.put(event);
  }
}
