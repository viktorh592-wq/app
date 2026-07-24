/// Chat message collection (FR-004). Messages belong to an event and are
/// created by a participant (Entity_Relationships.md).
import 'package:pokatuha/database/base_entity.dart';

class MessageCollection extends BaseEntity {
  String eventId = '';
  String authorId = '';

  /// MessageKind enum stored as string.
  String kind = 'text';

  String text = '';

  /// Path / id of an image attachment when kind == image.
  String? imagePath;

  /// Replied message id when kind == reply.
  String? replyToId;

  /// Pinned flag (FR-004 — Pinned Messages).
  bool pinned = false;

  /// Reactions as a serialized map {emoji: count}.
  String? reactionsJson;

  /// Whether the current user has read it.
  bool read = false;

  int? readAt;

  @override
  Map<String, dynamic> toMap() => baseToMap()
    ..addAll({
      'eventId': eventId,
      'authorId': authorId,
      'kind': kind,
      'text': text,
      'imagePath': imagePath,
      'replyToId': replyToId,
      'pinned': pinned,
      'reactionsJson': reactionsJson,
      'read': read,
      'readAt': readAt,
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
    pinned = m['pinned'] as bool? ?? false;
    reactionsJson = m['reactionsJson'] as String?;
    read = m['read'] as bool? ?? false;
    readAt = (m['readAt'] as num?)?.toInt();
  }

  static MessageCollection fromMap(Map<String, dynamic> m) =>
      MessageCollection()..applyMap(m);
}
