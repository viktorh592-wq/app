/// Notification collection (Notifications.md). Belongs to a User and an Event
/// (Entity_Relationships.md).
import 'package:pokatuha/database/base_entity.dart';

class NotificationCollection extends BaseEntity {
  String userId = '';
  String? eventId;

  /// NotificationCategory enum stored as string.
  String category = 'newMessage';

  String title = '';
  String body = '';

  bool read = false;

  int? sentAt;
  int? readAt;

  /// Whether this notification was delivered via FCM wake-up (ADR-003).
  bool viaFcm = false;

  @override
  Map<String, dynamic> toMap() => baseToMap()
    ..addAll({
      'userId': userId,
      'eventId': eventId,
      'category': category,
      'title': title,
      'body': body,
      'read': read,
      'sentAt': sentAt,
      'readAt': readAt,
      'viaFcm': viaFcm,
    });

  @override
  void applyMap(Map<String, dynamic> m) {
    baseFromMap(m);
    userId = m['userId'] as String? ?? '';
    eventId = m['eventId'] as String?;
    category = m['category'] as String? ?? 'newMessage';
    title = m['title'] as String? ?? '';
    body = m['body'] as String? ?? '';
    read = m['read'] as bool? ?? false;
    sentAt = (m['sentAt'] as num?)?.toInt();
    readAt = (m['readAt'] as num?)?.toInt();
    viaFcm = m['viaFcm'] as bool? ?? false;
  }

  static NotificationCollection fromMap(Map<String, dynamic> m) =>
      NotificationCollection()..applyMap(m);
}
