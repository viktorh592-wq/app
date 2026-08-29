/// Local database service (ADR-004 → ADR-005: Sembast). Pure-Dart,
/// offline-first, no code generation. All data stays on the device
/// (Local-First — ADR-001). Default activity types are seeded (README.md).
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sembast/sembast_memory.dart';

import 'package:pokatuha/core/constants/app_constants.dart';
import 'package:pokatuha/core/errors/app_error.dart';
import 'package:pokatuha/core/utils/timestamps.dart';
import 'package:pokatuha/core/utils/uuid.dart';
import 'package:pokatuha/database/base_entity.dart';
import 'package:pokatuha/database/collections/activity_type_collection.dart';
import 'package:pokatuha/database/collections/archive_collection.dart';
import 'package:pokatuha/database/collections/attachment_collection.dart';
import 'package:pokatuha/database/collections/event_collection.dart';
import 'package:pokatuha/database/collections/group_collection.dart';
import 'package:pokatuha/database/collections/group_member_collection.dart';
import 'package:pokatuha/database/collections/message_collection.dart';
import 'package:pokatuha/database/collections/notification_collection.dart';
import 'package:pokatuha/database/collections/participant_collection.dart';
import 'package:pokatuha/database/collections/photo_collection.dart';
import 'package:pokatuha/database/collections/poll_collection.dart';
import 'package:pokatuha/database/collections/route_collection.dart';
import 'package:pokatuha/database/collections/settings_collection.dart';
import 'package:pokatuha/database/collections/statistics_collection.dart';
import 'package:pokatuha/database/collections/theme_collection.dart';
import 'package:pokatuha/database/collections/track_point_collection.dart';
import 'package:pokatuha/database/collections/user_collection.dart';
import 'package:pokatuha/database/collections/video_collection.dart';
import 'package:pokatuha/database/collections/vote_collection.dart';

class DatabaseService {
  DatabaseService._(this._db);

  final Database _db;

  static Future<DatabaseService> open() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final dbPath = p.join(dir.path, '${AppConstants.databaseName}.db');
      final factory = databaseFactoryIo;
      final db = await factory.openDatabase(dbPath);
      final service = DatabaseService._(db);
      await service._seedDefaults();
      return service;
    } catch (e) {
      throw DatabaseError('Failed to open database: $e');
    }
  }

  /// In-memory constructor for tests (no platform file IO required). Each
  /// call opens a fresh, isolated database so tests never share state.
  static int _memoryCounter = 0;
  static Future<DatabaseService> memory() async {
    _memoryCounter += 1;
    final db = await databaseFactoryMemory
        .openDatabase('${AppConstants.databaseName}_test_$_memoryCounter.db');
    final service = DatabaseService._(db);
    await service._seedDefaults();
    return service;
  }

  Future<void> close() async => _db.close();

  Database get raw => _db;

  /// Default activity types (README.md). Idempotent — seeded once.
  Future<void> _seedDefaults() async {
    final store = activityTypesStore;
    final existing = await store.count();
    if (existing > 0) return;
    final now = Timestamps.nowUtc();
    final types = defaultActivityTypeLabels.entries.map((entry) {
      final t = ActivityTypeCollection()
        ..id = UuidGenerator.generate()
        ..createdAt = now
        ..updatedAt = now
        ..key = entry.key
        ..label = entry.value
        ..icon = 'directions_bike'
        ..isBuiltIn = true;
      return t;
    }).toList();
    await store.putAll(types);
  }

  Future<String> get mediaDir async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'media');
  }

  // --- Typed stores (one per collection) ---
  late final TypedStore<UserCollection> usersStore =
      TypedStore(_db, 'users', UserCollection.fromMap);
  late final TypedStore<EventCollection> eventsStore =
      TypedStore(_db, 'events', EventCollection.fromMap);
  late final TypedStore<GroupCollection> groupsStore =
      TypedStore(_db, 'groups', GroupCollection.fromMap);
  late final TypedStore<GroupMemberCollection> groupMembersStore =
      TypedStore(_db, 'group_members', GroupMemberCollection.fromMap);
  late final TypedStore<ParticipantCollection> participantsStore =
      TypedStore(_db, 'participants', ParticipantCollection.fromMap);
  late final TypedStore<MessageCollection> messagesStore =
      TypedStore(_db, 'messages', MessageCollection.fromMap);
  late final TypedStore<PollCollection> pollsStore =
      TypedStore(_db, 'polls', PollCollection.fromMap);
  late final TypedStore<VoteCollection> votesStore =
      TypedStore(_db, 'votes', VoteCollection.fromMap);
  late final TypedStore<RouteCollection> routesStore =
      TypedStore(_db, 'routes', RouteCollection.fromMap);
  late final TypedStore<TrackPointCollection> trackPointsStore =
      TypedStore(_db, 'track_points', TrackPointCollection.fromMap);
  late final TypedStore<ArchiveCollection> archivesStore =
      TypedStore(_db, 'archives', ArchiveCollection.fromMap);
  late final TypedStore<NotificationCollection> notificationsStore =
      TypedStore(_db, 'notifications', NotificationCollection.fromMap);
  late final TypedStore<PhotoCollection> photosStore =
      TypedStore(_db, 'photos', PhotoCollection.fromMap);
  late final TypedStore<VideoCollection> videosStore =
      TypedStore(_db, 'videos', VideoCollection.fromMap);
  late final TypedStore<AttachmentCollection> attachmentsStore =
      TypedStore(_db, 'attachments', AttachmentCollection.fromMap);
  late final TypedStore<StatisticsCollection> statisticsStore =
      TypedStore(_db, 'statistics', StatisticsCollection.fromMap);
  late final TypedStore<ThemeCollection> themesStore =
      TypedStore(_db, 'themes', ThemeCollection.fromMap);
  late final TypedStore<SettingsCollection> settingsStore =
      TypedStore(_db, 'settings', SettingsCollection.fromMap);
  late final TypedStore<ActivityTypeCollection> activityTypesStore =
      TypedStore(_db, 'activity_types', ActivityTypeCollection.fromMap);
}

/// Typed wrapper around a Sembast store providing CRUD + query helpers that
/// preserve the entity standards (soft-delete filtering is the caller's
/// responsibility via [Filter]s).
class TypedStore<T extends BaseEntity> {
  TypedStore(this._db, String name, this._fromMap)
      : _store = stringMapStoreFactory.store(name);

  final Database _db;
  final StoreRef<String, Map<String, dynamic>> _store;
  final T Function(Map<String, dynamic>) _fromMap;

  Future<T?> getById(String id) async {
    final map = await _store.record(id).get(_db);
    return map == null ? null : _fromMap(map);
  }

  Future<List<T>> find({
    Filter? filter,
    List<SortOrder>? sortOrders,
    int? limit,
    int? offset,
  }) async {
    final snapshots = await _store.find(
      _db,
      finder: Finder(
        filter: filter,
        sortOrders: sortOrders,
        limit: limit,
        offset: offset,
      ),
    );
    return snapshots.map((s) => _fromMap(s.value)).toList();
  }

  Future<int> count({Filter? filter}) async =>
      _store.count(_db, filter: filter);

  Future<T> put(T entity) async {
    await _store.record(entity.id).put(_db, entity.toMap());
    return entity;
  }

  Future<void> putAll(List<T> entities) async {
    await _db.transaction((txn) async {
      for (final e in entities) {
        await _store.record(e.id).put(txn, e.toMap());
      }
    });
  }

  /// Raw record access within a transaction (used by poll vote recompute).
  Future<List<T>> findInTxn(Transaction txn,
      {Filter? filter, List<SortOrder>? sortOrders}) async {
    final snapshots = await _store.find(
      txn,
      finder: Finder(filter: filter, sortOrders: sortOrders),
    );
    return snapshots.map((s) => _fromMap(s.value)).toList();
  }

  Future<void> putInTxn(Transaction txn, T entity) async {
    await _store.record(entity.id).put(txn, entity.toMap());
  }
}

/// Built-in activity type keys -> labels (README.md).
const Map<String, String> defaultActivityTypeLabels = {
  'MTB': 'MTB',
  'XC': 'XC',
  'Enduro': 'Enduro',
  'Downhill': 'Downhill',
  'Gravel': 'Gravel',
  'Road': 'Road',
  'BMX': 'BMX',
  'E-Bike': 'E-Bike',
  'Hiking': 'Hiking',
  'Running': 'Running',
};
