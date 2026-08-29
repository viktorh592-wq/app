/// Chat message collection (FR-004). Messages belong to an event and are
/// created by a participant (Entity_Relationships.md).
///
/// V3 Sprint 3 (FIX_PLAN S3-T1) — extended to support the V2 Telegram-style
/// chat (TELEGRAM_STYLE_CHAT.md): reply / forward / pin / delivery state /
/// read receipts / reactions / structured attachments (image, video, voice,
/// document, location, route, poll).
import 'dart:convert';

import 'package:pokatuha/database/base_entity.dart';

/// Delivery state lifecycle of an outgoing message
/// (FIX_PLAN S3-T10, TELEGRAM_STYLE_CHAT.md §7):
///   queued → sending → delivered → synced
enum DeliveryState {
  queued,
  sending,
  delivered,
  synced;

  static DeliveryState fromString(String? value) {
    switch (value) {
      case 'sending':
        return DeliveryState.sending;
      case 'delivered':
        return DeliveryState.delivered;
      case 'synced':
        return DeliveryState.synced;
      case 'queued':
      default:
        return DeliveryState.queued;
    }
  }
}

/// Attachment kind — telegraph-style structured payload
/// (TELEGRAM_STYLE_CHAT.md §9, S3-T7..S3-T9, S3-T12).
enum AttachmentType {
  image,
  video,
  voice,
  document,
  location,
  route,
  poll;

  static AttachmentType? fromString(String? value) {
    if (value == null) return null;
    for (final t in AttachmentType.values) {
      if (t.name == value) return t;
    }
    return null;
  }
}

class MessageCollection extends BaseEntity {
  String eventId = '';
  String authorId = '';

  /// MessageKind enum stored as string.
  String kind = 'text';

  String text = '';

  /// Path / id of an image attachment when kind == image (legacy V1 field,
  /// kept for backwards compatibility — superseded by [attachmentPath]).
  String? imagePath;

  /// Replied message id (V2 §4 — Replies). Renamed in V2 docs to `replyTo`
  /// but kept as `replyToId` in storage for backwards compatibility with
  /// Sprint 2 data. New code reads through [replyTo] below.
  String? replyToId;

  /// Forwarded-from user id (V2 §4 — Forwards, S3-T4).
  String? forwardedFrom;

  /// Pinned flag (FR-004 — Pinned Messages, S3-T5).
  bool pinned = false;

  /// Reactions as a serialized JSON map {emoji: [userId, ...]}
  /// (V2 §6 — Reactions, S3-T2). Replaces the legacy count-only format.
  String? reactionsJson;

  /// Whether the current user has read it (legacy V1 single-user flag).
  bool read = false;

  int? readAt;

  // === Sprint 3 V2 extensions ===

  /// Delivery state of an outgoing message (S3-T10). Stored as the enum name.
  String deliveryState = DeliveryState.queued.name;

  /// List of userIds who have read the message (V2 §8 — Read state, S3-T11).
  /// Serialized as JSON array string.
  String? readByJson;

  /// Local file path of the structured attachment (S3-T6..S3-T9, S3-T12).
  /// For [AttachmentType.image] this is the compressed JPEG path; for
  /// [AttachmentType.voice] the recorded AAC/M4A path; for documents the
  /// downloaded file path. null for non-attachment messages.
  String? attachmentPath;

  /// One of [AttachmentType] names — describes the payload kind.
  String? attachmentType;

  /// JSON-encoded metadata for the attachment (duration for voice, width /
  /// height for images, lat / lng for location, route id for routes, etc.).
  String? attachmentMeta;

  @override
  Map<String, dynamic> toMap() => baseToMap()
    ..addAll({
      'eventId': eventId,
      'authorId': authorId,
      'kind': kind,
      'text': text,
      'imagePath': imagePath,
      'replyToId': replyToId,
      'forwardedFrom': forwardedFrom,
      'pinned': pinned,
      'reactionsJson': reactionsJson,
      'read': read,
      'readAt': readAt,
      'deliveryState': deliveryState,
      'readByJson': readByJson,
      'attachmentPath': attachmentPath,
      'attachmentType': attachmentType,
      'attachmentMeta': attachmentMeta,
    });

  @override
  void applyMap(Map<String, dynamic> m) {
    baseFromMap(m);
    eventId = m['eventId'] as String? ?? '';
    authorId = m['authorId'] as String? ?? '';
    kind = m['kind'] as String? ?? 'text';
    text = m['text'] as String? ?? '';
    imagePath = m['imagePath'] as String?;
    replyToId = m['replyToId'] as String?;
    forwardedFrom = m['forwardedFrom'] as String?;
    pinned = m['pinned'] as bool? ?? false;
    reactionsJson = m['reactionsJson'] as String?;
    read = m['read'] as bool? ?? false;
    readAt = (m['readAt'] as num?)?.toInt();
    deliveryState = m['deliveryState'] as String? ?? DeliveryState.queued.name;
    readByJson = m['readByJson'] as String?;
    attachmentPath = m['attachmentPath'] as String?;
    attachmentType = m['attachmentType'] as String?;
    attachmentMeta = m['attachmentMeta'] as String?;
  }

  static MessageCollection fromMap(Map<String, dynamic> m) =>
      MessageCollection()..applyMap(m);

  // --- Convenience accessors (V2) ---

  /// Alias for [replyToId] matching V2 TELEGRAM_STYLE_CHAT.md naming.
  String? get replyTo => replyToId;
  set replyTo(String? v) => replyToId = v;

  /// Alias for [pinned] matching V2 TELEGRAM_STYLE_CHAT.md naming.
  bool get isPinned => pinned;
  set isPinned(bool v) => pinned = v;

  /// Parsed reactions map {emoji: [userIds]} (S3-T2). Empty when unset.
  Map<String, List<String>> get reactions => reactionsJson == null
      ? <String, List<String>>{}
      : ((jsonDecode(reactionsJson!) as Map<String, dynamic>).map(
          (emoji, raw) => MapEntry(
            emoji,
            (raw as List).map((e) => e.toString()).toList(),
          ),
        ));

  /// Sets the reactions map and serializes it back to [reactionsJson].
  set reactions(Map<String, List<String>> value) {
    reactionsJson = value.isEmpty
        ? null
        : jsonEncode(value.map((k, v) => MapEntry(k, v)));
  }

  /// Parsed list of userIds that have read the message (S3-T11).
  List<String> get readBy => readByJson == null
      ? <String>[]
      : (jsonDecode(readByJson!) as List)
          .map((e) => e.toString())
          .toList();

  set readBy(List<String> value) {
    readByJson = value.isEmpty ? null : jsonEncode(value);
  }

  /// Typed attachment kind (null when the message has no structured payload).
  AttachmentType? get attachment => AttachmentType.fromString(attachmentType);

  /// Typed delivery state for [deliveryState].
  DeliveryState get delivery => DeliveryState.fromString(deliveryState);

  /// Parsed attachment metadata map (empty when unset).
  Map<String, dynamic> get attachmentMetaMap => attachmentMeta == null
      ? <String, dynamic>{}
      : jsonDecode(attachmentMeta!) as Map<String, dynamic>;

  set attachmentMetaMap(Map<String, dynamic>? value) {
    attachmentMeta = value == null || value.isEmpty
        ? null
        : jsonEncode(value);
  }
}
