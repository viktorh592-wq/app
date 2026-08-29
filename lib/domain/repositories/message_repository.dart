/// Chat message repository (FR-004). Messages belong to an event and are
/// created by a participant (Entity_Relationships.md).
///
/// V3 Sprint 3 (FIX_PLAN S3-T1..T11) — adds the V2 Telegram-style operations:
/// pin / unpin, setReaction (toggle per user), setDeliveryState, markRead by
/// userId, forward, and a pinned stream for the chat top-bar (S3-T5).
import 'dart:async';
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

  /// A single message by id (null when missing or soft-deleted).
  Future<MessageCollection?> getById(String id) async {
    final m = await _store.getById(id);
    return (m != null && !m.isDeleted) ? m : null;
  }

  Future<List<MessageCollection>> pinned(String eventId) async => _store.find(
        filter: Filter.equals('eventId', eventId) &
            Filter.equals('pinned', true) &
            Filter.equals('isDeleted', false),
        sortOrders: [SortOrder('createdAt', false)],
      );

  /// Pinned messages stream (S3-T5 — top-bar with preview + count). Emits a
  /// fresh list each time any pinned message is created / toggled.
  Stream<List<MessageCollection>> pinnedStream(String eventId) {
    final controller = StreamController<List<MessageCollection>>();
    Future<void> emit() async {
      final list = await pinned(eventId);
      if (!controller.isClosed) controller.add(list);
    }

    // Emit initial snapshot, then re-emit on every store mutation.
    // Sembast has no native change stream — we re-query on each put via the
    // [notifyStream] hook below.
    emit();
    _notifyControllers.add(controller);
    controller.onCancel = () {
      _notifyControllers.remove(controller);
      controller.close();
    };
    return controller.stream;
  }

  /// Simple broadcast controllers used to fan-out store mutations to active
  /// pinned-stream subscribers. Local-first Sembast has no native change
  /// feed, so we re-query after each write.
  final Set<StreamController<List<MessageCollection>>> _notifyControllers =
      <StreamController<List<MessageCollection>>>{};

  Future<void> _notifyPinned(String eventId) async {
    if (_notifyControllers.isEmpty) return;
    final list = await pinned(eventId);
    for (final c in _notifyControllers.toList()) {
      if (!c.isClosed) c.add(list);
    }
  }

  Future<MessageCollection> sendText({
    required String eventId,
    required String authorId,
    required String text,
    String? replyToId,
    String? forwardedFrom,
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
      ..kind = forwardedFrom != null
          ? MessageKind.text.name
          : (replyToId != null
              ? MessageKind.reply.name
              : MessageKind.text.name)
      ..text = text.trim()
      ..replyToId = replyToId
      ..forwardedFrom = forwardedFrom
      ..deliveryState = DeliveryState.queued.name
      ..createdBy = authorId;
    final saved = await _store.put(msg);
    await _notifyPinned(eventId);
    return saved;
  }

  /// Generic structured-attachment send (S3-T6..S3-T9, S3-T12). Used by the
  /// attachments sheet for image / voice / document / location / route. The
  /// caller is responsible for persisting the binary payload to disk before
  /// calling this and passing the resulting local path.
  Future<MessageCollection> sendAttachment({
    required String eventId,
    required String authorId,
    required AttachmentType type,
    required String attachmentPath,
    String? caption,
    String? replyToId,
    Map<String, dynamic>? meta,
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
      ..kind = MessageKind.text.name
      ..text = caption?.trim() ?? ''
      ..replyToId = replyToId
      ..attachmentPath = attachmentPath
      ..attachmentType = type.name
      ..attachmentMetaMap = meta
      ..deliveryState = DeliveryState.queued.name
      ..createdBy = authorId;
    final saved = await _store.put(msg);
    await _notifyPinned(eventId);
    return saved;
  }

  /// Legacy image send kept for backwards compatibility with Sprint 2 tests.
  Future<MessageCollection> sendImage({
    required String eventId,
    required String authorId,
    required String imagePath,
    String? caption,
    String? replyToId,
  }) async =>
      sendAttachment(
        eventId: eventId,
        authorId: authorId,
        type: AttachmentType.image,
        attachmentPath: imagePath,
        caption: caption,
        replyToId: replyToId,
      );

  /// Forward a message to another event (S3-T4). Creates a fresh message in
  /// the target event attributed to the current user (forwardedFrom carries
  /// the original author id).
  Future<MessageCollection> forward({
    required MessageCollection source,
    required String toEventId,
    required String byUserId,
  }) async {
    final now = Timestamps.nowUtc();
    final msg = MessageCollection()
      ..id = UuidGenerator.generate()
      ..createdAt = now
      ..updatedAt = now
      ..version = 1
      ..isDeleted = false
      ..eventId = toEventId
      ..authorId = byUserId
      ..kind = source.kind
      ..text = source.text
      ..imagePath = source.imagePath
      ..attachmentPath = source.attachmentPath
      ..attachmentType = source.attachmentType
      ..attachmentMeta = source.attachmentMeta
      ..forwardedFrom = source.authorId
      ..deliveryState = DeliveryState.queued.name
      ..createdBy = byUserId;
    final saved = await _store.put(msg);
    await _notifyPinned(toEventId);
    return saved;
  }

  /// Toggle the pinned flag (legacy V1 entry point kept for tests / menu).
  Future<void> togglePin(MessageCollection message) async {
    message
      ..pinned = !message.pinned
      ..touch(Timestamps.nowUtc());
    await _store.put(message);
    await _notifyPinned(message.eventId);
  }

  /// Pin a message (S3-T5 — Long-press → «Закрепить»).
  Future<void> pin(MessageCollection message) async {
    if (message.pinned) return;
    message
      ..pinned = true
      ..touch(Timestamps.nowUtc());
    await _store.put(message);
    await _notifyPinned(message.eventId);
  }

  /// Unpin a message (S3-T5).
  Future<void> unpin(MessageCollection message) async {
    if (!message.pinned) return;
    message
      ..pinned = false
      ..touch(Timestamps.nowUtc());
    await _store.put(message);
    await _notifyPinned(message.eventId);
  }

  /// Toggle a reaction by user (S3-T2). Adding the same emoji again removes it.
  /// Reactions are stored as `{emoji: [userId, ...]}`.
  Future<void> setReaction({
    required MessageCollection message,
    required String emoji,
    required String userId,
  }) async {
    final reactions = Map<String, List<String>>.from(message.reactions);
    final existing = reactions[emoji] ?? <String>[];
    if (existing.contains(userId)) {
      existing.remove(userId);
      if (existing.isEmpty) {
        reactions.remove(emoji);
      } else {
        reactions[emoji] = existing;
      }
    } else {
      existing.add(userId);
      reactions[emoji] = existing;
    }
    message
      ..reactions = reactions
      ..touch(Timestamps.nowUtc());
    await _store.put(message);
    await _notifyPinned(message.eventId);
  }

  /// Legacy single-counter reaction kept for backwards compatibility with
  /// Sprint 2 tests (`addReaction` increments an int counter per emoji).
  Future<void> addReaction(MessageCollection message, String emoji) async {
    final raw = message.reactionsJson == null
        ? <String, dynamic>{}
        : jsonDecode(message.reactionsJson!) as Map<String, dynamic>;
    final counter = (raw[emoji] as num?)?.toInt() ?? 0;
    raw[emoji] = counter + 1;
    message
      ..reactionsJson = jsonEncode(raw)
      ..touch(Timestamps.nowUtc());
    await _store.put(message);
    await _notifyPinned(message.eventId);
  }

  /// Set the delivery state of an outgoing message (S3-T10).
  Future<void> setDeliveryState(
    MessageCollection message,
    DeliveryState state,
  ) async {
    if (message.deliveryState == state.name) return;
    message
      ..deliveryState = state.name
      ..touch(Timestamps.nowUtc());
    await _store.put(message);
  }

  /// Mark a message as read by [userId] (S3-T11 — Read state).
  Future<void> markRead(MessageCollection message, {String? userId}) async {
    final now = Timestamps.nowUtc();
    // Legacy single-user read flag — kept for the existing tests / unread
    // counter on the chat tab badge.
    if (!message.read) {
      message
        ..read = true
        ..readAt = now;
    }
    if (userId != null) {
      final readers = message.readBy.toList()..add(userId);
      // De-duplicate while preserving order.
      message.readBy = readers.toSet().toList();
    }
    message.touch(now);
    await _store.put(message);
  }

  /// Mark all incoming messages of [eventId] as read by [userId] on chat
  /// open (S3-T11 — «при открытии чата count непрочитанных обнуляется»).
  Future<void> markAllReadByUser({
    required String eventId,
    required String userId,
  }) async {
    final list = await byEvent(eventId);
    final now = Timestamps.nowUtc();
    for (final m in list) {
      if (m.authorId == userId) continue; // outgoing
      if (m.read && m.readBy.contains(userId)) continue;
      if (!m.read) {
        m
          ..read = true
          ..readAt = now;
      }
      if (!m.readBy.contains(userId)) {
        m.readBy = [...m.readBy, userId];
      }
      m.touch(now);
      await _store.put(m);
    }
  }

  Future<int> unreadCount(String eventId) async => _store.count(
        filter: Filter.equals('eventId', eventId) &
            Filter.equals('read', false) &
            Filter.equals('isDeleted', false),
      );

  /// Search messages of an event by free-text (S3-T13 — Chat menu → Search).
  Future<List<MessageCollection>> search({
    required String eventId,
    required String query,
  }) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    final list = await byEvent(eventId);
    return list.where((m) => m.text.toLowerCase().contains(q)).toList();
  }

  /// All media messages (image / video) of an event (S3-T13 — Chat menu →
  /// Media).
  Future<List<MessageCollection>> media(String eventId) async {
    final list = await byEvent(eventId);
    return list
        .where((m) =>
            m.attachmentType == AttachmentType.image.name ||
            m.attachmentType == AttachmentType.video.name)
        .toList();
  }

  /// All document messages (S3-T13 — Chat menu → Files).
  Future<List<MessageCollection>> files(String eventId) async {
    final list = await byEvent(eventId);
    return list
        .where((m) => m.attachmentType == AttachmentType.document.name)
        .toList();
  }

  /// All route messages (S3-T13 — Chat menu → Shared routes).
  Future<List<MessageCollection>> routes(String eventId) async {
    final list = await byEvent(eventId);
    return list
        .where((m) => m.attachmentType == AttachmentType.route.name)
        .toList();
  }

  /// Export the full chat history of an event as JSON (S3-T13 — Export).
  /// Local-only file: never uploaded, never sent to a backend (ADR-001).
  Future<String> exportJson(String eventId) async {
    final list = await byEvent(eventId);
    final payload = {
      'eventId': eventId,
      'exportedAt': Timestamps.nowUtc(),
      'messages': list.map((m) => m.toMap()).toList(),
    };
    return jsonEncode(payload);
  }
}
