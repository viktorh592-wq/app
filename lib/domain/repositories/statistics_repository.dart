/// Statistics repository (Statistics module). Per-event / per-user stats.
import 'package:sembast/sembast.dart';

import 'package:pokatuha/core/utils/timestamps.dart';
import 'package:pokatuha/core/utils/uuid.dart';
import 'package:pokatuha/database/collections/statistics_collection.dart';
import 'package:pokatuha/database/database.dart';

class StatisticsRepository {
  StatisticsRepository(this._db);
  final DatabaseService _db;

  TypedStore<StatisticsCollection> get _store => _db.statisticsStore;

  Future<List<StatisticsCollection>> byUser(String userId) async => _store.find(
        filter:
            Filter.equals('userId', userId) & Filter.equals('isDeleted', false),
      );

  Future<StatisticsCollection?> byEventAndUser(
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

  Future<StatisticsCollection> save(StatisticsCollection stats) async {
    if (stats.id.isEmpty) {
      final now = Timestamps.nowUtc();
      stats
        ..id = UuidGenerator.generate()
        ..createdAt = now
        ..updatedAt = now
        ..version = 1
        ..isDeleted = false;
    } else {
      stats.touch(Timestamps.nowUtc());
    }
    return _store.put(stats);
  }
}
