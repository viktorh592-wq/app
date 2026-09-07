/// FCM push notification service (V3.0.7 — user-reported bug 3 & 4).
///
/// ADR-003 philosophy is preserved: FCM never transports chat / GPS / media
/// PAYLOADS. But FCM DOES carry lightweight metadata (groupId, eventId,
/// authorName) so the receiver can show a status-bar notification even when:
///   * the app is fully killed (swipe-away on aggressive OEMs);
///   * the device is on a mobile network (the MQTT relay may also be down);
///   * the foreground service was killed by Android Doze / battery optimizer.
///
/// The chat content itself is NEVER in the FCM payload — when the user taps
/// the notification and the app reopens, ChatSyncService.requestHistory()
/// pulls the actual message bodies from peers (LAN UDP or MQTT relay). The
/// FCM data message only carries:
///   { type: "chat", groupId, eventId, authorId, authorName, title }
///
/// When the app is in the foreground, FCM messages are silently consumed
/// (ChatSyncService already shows the message in the chat tab). When the app
/// is backgrounded, FCM triggers a high-priority data message that wakes the
/// process and surfaces a local notification via SystemNotificationService.
///
/// Privacy note: per ADR-001, the app never sends user data to a server.
/// FCM data messages carry only the minimum metadata needed to wake the
/// device and show a localized title. The actual message text is fetched
/// peer-to-peer after the app wakes up. The author name is sent because
/// without it the notification would show «User xxxxxx» again — this is
/// the user-visible fix from problem 5.
library;

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'package:pokatuha/domain/services/system_notification_service.dart';

/// Callback type for foreground FCM data messages carrying chat metadata.
typedef FcmChatHandler = void Function(Map<String, dynamic> data);

/// Top-level FCM background handler — MUST be a top-level function so the
/// background isolate can reach it. Shows a local notification immediately
/// because the foreground ChatSyncService is not running when the app is
/// killed.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized in the background isolate.
  await Firebase.initializeApp();
  final data = message.data;
  final type = data['type'] as String?;
  if (type != 'chat') return;
  final title = data['title'] as String? ?? 'Pokatuha';
  final authorName = data['authorName'] as String? ?? '';
  final text = data['text'] as String? ?? '';
  final body = text.isEmpty
      ? authorName
      : (authorName.isEmpty ? text : '$authorName: $text');
  if (body.isEmpty) return;
  final tag = data['groupId'] as String? ?? data['eventId'] as String? ?? 'chat';
  final notifier = SystemNotificationService();
  await notifier.init();
  await notifier.showChat(tag: tag, title: title, body: body);
}

class FcmPushService {
  FcmPushService({FirebaseMessaging? instance})
      : _messaging = instance ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  bool _initialized = false;
  String? _token;
  FcmChatHandler? _foregroundHandler;

  /// The FCM token of this device, or null when initialization failed or
  /// permission was denied. Other services pass this to peers so they can
  /// send wake-up pushes (the registration is shared over the existing
  /// P2P transport — never uploaded to any backend).
  String? get token => _token;

  /// Initializes Firebase Messaging, requests notification permission and
  /// registers the background handler. Idempotent — safe to call from both
  /// main() and from a settings UI.
  Future<void> init({FcmChatHandler? foregroundHandler}) async {
    if (_initialized) return;
    _foregroundHandler = foregroundHandler;
    try {
      // Register the background isolate handler FIRST so a data message
      // arriving before init completes still surfaces a notification.
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      // Foreground messages: when the app is open, the chat tab itself is
      // the surface — we do NOT show a notification (the user is already
      // looking at the chat). Just hand the data to the registered handler
      // so ChatSyncService can refresh if needed.
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);

      // Notification permission (Android 13+ POST_NOTIFICATIONS, iOS prompt).
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus !=
              AuthorizationStatus.provisional) {
        // Permission denied — chat still works, just no FCM wakeup. The
        // foreground service stays as the backup notification path.
        _initialized = true;
        return;
      }

      _token = await _messaging.getToken();
      _initialized = true;
    } catch (_) {
      // Firebase may be unavailable (no Google Play Services, missing
      // config on a forked build). Chat keeps working over MQTT / UDP.
      _initialized = true;
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] as String?;
    if (type != 'chat') return;
    _foregroundHandler?.call(data);
  }

  /// Subscribes this device to the FCM topic for [groupId]. We use a topic
  /// per group: any peer that knows the group id (i.e. any member) can
  /// publish a wake-up via the relay, and FCM delivers to all subscribers
  /// of that topic. The topic name is the group id — a 122-bit UUID that
  /// is itself secret (the QR payload carries it).
  ///
  /// Privacy: the topic name does NOT reveal the group name, members or
  /// message contents. FCM only sees that some device subscribed to a
  /// random-looking topic. ADR-001 (local-first) is preserved — the message
  /// body never transits FCM.
  Future<void> subscribeToGroup(String groupId) async {
    if (!_initialized) return;
    try {
      await _messaging.subscribeToTopic('group_$groupId');
    } catch (_) {
      // Best-effort — peers may also wake via MQTT.
    }
  }

  Future<void> unsubscribeFromGroup(String groupId) async {
    if (!_initialized) return;
    try {
      await _messaging.unsubscribeFromTopic('group_$groupId');
    } catch (_) {}
  }

  /// True when FCM is available and permission was granted on this device.
  bool get isAvailable => _initialized && _token != null;

  /// Visible for tests.
  @visibleForTesting
  bool get initializedForTest => _initialized;
}
