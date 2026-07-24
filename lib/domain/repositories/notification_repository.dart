/// Notification repository (Notifications.md). Belongs to a User and an Event
/// (Entity_Relationships.md).
import 'package:sembast/sembast.dart';

import 'package:pokatuha/core/utils/timestamps.dart';
import 'package:pokatuha/core/utils/uuid.dart';
import 'package:pokatuha/database/collections/notification_collection.dart';
import 'package:pokatuha/database/database.dart';
import 'package:pokatuha/domain/enums/enums.dart';

class NotificationRepository {
  NotificationRepository(this._db);
  final DatabaseService _db;

  TypedStore<NotificationCollection> get _store => _db.notificationsStore;

  Future<List<NotificationCollection>> forUser(String userId,
      {bool unreadOnly = false}) async {
    Filter filter =
        Filter.equals('userId', userId) & Filter.equals('isDeleted', false);
    if (unreadOnly) {
      filter = filter & Filter.equals('read', false);
    }
    return _store.find(
      filter: filter,
      sortOrders: [SortOrder('createdAt', false)],
    );
  }

  Future<int> unreadCount(String userId) async => _store.count(
        filter: Filter.equals('userId', userId) &
            Filter.equals('read', false) &
            Filter.equals('isDeleted', false),
      );

  Future<NotificationCollection> create({
    required String userId,
    required NotificationCategory category,
    required String title,
    required String body,
    String? eventId,
    bool viaFcm = false,
  }) async {
    final now = Timestamps.nowUtc();
    final n = NotificationCollection()
      ..id = UuidGenerator.generate()
      ..createdAt = now
      ..updatedAt = now
      ..version = 1
      ..isDeleted = false
      ..userId = userId
      ..eventId = eventId
      ..category = category.name
      ..title = title
      ..body = body
      ..sentAt = now
      ..viaFcm = viaFcm;
    return _store.put(n);
  }

  Future<void> markRead(NotificationCollection notification) async {
    if (notification.read) return;
    final now = Timestamps.nowUtc();
    notification
      ..read = true
      ..readAt = now
      ..touch(now);
    await _store.put(notification);
  }

  Future<void> markAllRead(String userId) async {
    final unread = await forUser(userId, unreadOnly: true);
    if (unread.isEmpty) return;
    final now = Timestamps.nowUtc();
    for (final n in unread) {
      n
        ..read = true
        ..readAt = now
        ..touch(now);
    }
    await _store.putAll(unread);
  }
}
