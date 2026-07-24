/// Chat message repository (FR-004). Messages belong to an event and are
/// created by a participant (Entity_Relationships.md).
import 'dart:convert';

import 'package:sembast/sembast.dart';

import 'package:pokatuha/core/errors/app_error.dart';
import 'package:pokatuha/core/utils/timestamps.dart';
import 'package:pokatuha/core/utils/uuid.dart';
import 'package:pokatuha/core/utils/validators.dart';
import 'package:pokatuha/database/collections/message_collection.dart';
import 'package:pokatuha/database/database.dart';
import 'package:pokatuha/domain/enums/enums.dart';

class MessageRepository {
  MessageRepository(this._db);
  final DatabaseService _db;

  TypedStore<MessageCollection> get _store => _db.messagesStore;

  /// Messages for an event, newest last (chat ordering).
  Future<List<MessageCollection>> byEvent(String eventId) async => _store.find(
        filter: Filter.equals('eventId', eventId) &
            Filter.equals('isDeleted', false),
        sortOrders: [SortOrder('createdAt')],
      );

  Future<List<MessageCollection>> pinned(String eventId) async => _store.find(
        filter: Filter.equals('eventId', eventId) &
            Filter.equals('pinned', true) &
            Filter.equals('isDeleted', false),
        sortOrders: [SortOrder('createdAt', false)],
      );

  Future<MessageCollection> sendText({
    required String eventId,
    required String authorId,
    required String text,
    String? replyToId,
  }) async {
    if (!Validators.isValidMessage(text)) {
      throw const ValidationError('Invalid message');
    }
    final now = Timestamps.nowUtc();
    final msg = MessageCollection()
      ..id = UuidGenerator.generate()
      ..createdAt = now
      ..updatedAt = now
      ..version = 1
      ..isDeleted = false
      ..eventId = eventId
      ..authorId = authorId
      ..kind =
          replyToId != null ? MessageKind.reply.name : MessageKind.text.name
      ..text = text.trim()
      ..replyToId = replyToId
      ..createdBy = authorId;
    return _store.put(msg);
  }

  Future<MessageCollection> sendImage({
    required String eventId,
    required String authorId,
    required String imagePath,
    String? caption,
    String? replyToId,
  }) async {
    final now = Timestamps.nowUtc();
    final msg = MessageCollection()
      ..id = UuidGenerator.generate()
      ..createdAt = now
      ..updatedAt = now
      ..version = 1
      ..isDeleted = false
      ..eventId = eventId
      ..authorId = authorId
      ..kind = MessageKind.image.name
      ..text = caption?.trim() ?? ''
      ..imagePath = imagePath
      ..replyToId = replyToId
      ..createdBy = authorId;
    return _store.put(msg);
  }

  Future<void> togglePin(MessageCollection message) async {
    message
      ..pinned = !message.pinned
      ..touch(Timestamps.nowUtc());
    await _store.put(message);
  }

  Future<void> addReaction(MessageCollection message, String emoji) async {
    final reactions = message.reactionsJson == null
        ? <String, int>{}
        : (jsonDecode(message.reactionsJson!) as Map<String, dynamic>)
            .cast<String, int>();
    reactions[emoji] = (reactions[emoji] ?? 0) + 1;
    message
      ..reactionsJson = jsonEncode(reactions)
      ..touch(Timestamps.nowUtc());
    await _store.put(message);
  }

  Future<void> markRead(MessageCollection message) async {
    if (message.read) return;
    final now = Timestamps.nowUtc();
    message
      ..read = true
      ..readAt = now
      ..touch(now);
    await _store.put(message);
  }

  Future<int> unreadCount(String eventId) async => _store.count(
        filter: Filter.equals('eventId', eventId) &
            Filter.equals('read', false) &
            Filter.equals('isDeleted', false),
      );
}
