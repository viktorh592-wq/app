/// Activity type repository (FR-002 — unlimited custom activity types).
import 'package:sembast/sembast.dart';

import 'package:pokatuha/core/utils/timestamps.dart';
import 'package:pokatuha/core/utils/uuid.dart';
import 'package:pokatuha/database/collections/activity_type_collection.dart';
import 'package:pokatuha/database/database.dart';

class ActivityTypeRepository {
  ActivityTypeRepository(this._db);
  final DatabaseService _db;

  TypedStore<ActivityTypeCollection> get _store => _db.activityTypesStore;

  Future<List<ActivityTypeCollection>> all() async => _store.find(
        filter: Filter.equals('isDeleted', false),
        sortOrders: [SortOrder('key')],
      );

  Future<ActivityTypeCollection?> byKey(String key) async {
    final list = await _store.find(
      filter: Filter.equals('key', key),
      limit: 1,
    );
    return list.isEmpty ? null : list.first;
  }

  Future<ActivityTypeCollection> createCustom({
    required String key,
    required String label,
    String icon = 'directions_bike',
    String? ownerId,
  }) async {
    final now = Timestamps.nowUtc();
    final type = ActivityTypeCollection()
      ..id = UuidGenerator.generate()
      ..createdAt = now
      ..updatedAt = now
      ..version = 1
      ..isDeleted = false
      ..key = key.trim()
      ..label = label.trim()
      ..icon = icon
      ..isBuiltIn = false
      ..ownerId = ownerId;
    return _store.put(type);
  }
}
