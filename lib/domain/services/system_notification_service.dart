/// System (status-bar) notifications for incoming chat messages
/// (V3.0.5 — user-reported bug 1: «не приходят оповещения о новых
/// сообщениях если абонент вышел из приложения»).
///
/// The pre-existing [NotificationService] only PERSISTS notifications into
/// the local Sembast notification-center collection — nothing was ever
/// shown in the Android status bar. This service wraps
/// `flutter_local_notifications` (already declared in pubspec.yaml but
/// previously unused) to actually surface messages while the app is
/// backgrounded.
///
/// The chat ingest path (ChatSyncService) calls [ChatNotifications.showChat]
/// only when the app is NOT in the foreground; when the user brings the app
/// back, the UI layer cancels the chat notifications so they never point to
/// already-read messages.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Transport-agnostic sink used by the chat sync layer. Abstract so unit
/// tests can inject a fake without the platform plugin.
abstract class ChatNotifications {
  /// Shows (or replaces — keyed by [tag]) the notification for one chat.
  Future<void> showChat({
    required String tag,
    required String title,
    required String body,
  });

  /// Removes every chat notification (called when the app is resumed).
  Future<void> cancelAllChat();
}

class SystemNotificationService implements ChatNotifications {
  SystemNotificationService();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Localized channel name — configured from the UI layer where l10n is
  /// reachable (the channel is created on first show, Android 8+).
  String _chatChannelName = 'Pokatuha';

  static const String _chatChannelId = 'pokatuha_chat_messages';
  static const String _chatChannelDescription =
      'Pokatuha chat messages received while the app is in the background';

  /// Whether the platform side is ready to show notifications.
  bool get isInitialized => _initialized;

  /// Configures the localized channel label (best-effort, before the first
  /// notification is shown).
  void configure({required String chatChannelName}) {
    if (chatChannelName.trim().isNotEmpty) {
      _chatChannelName = chatChannelName.trim();
    }
  }

  /// Initializes the plugin. Safe to call multiple times and from a
  /// background engine isolate.
  Future<void> init() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _onResponse,
    );
    _initialized = true;
  }

  /// Requests the Android 13+ POST_NOTIFICATIONS runtime permission.
  /// Returns true when granted (or when no permission dialog is required).
  /// A denial is non-fatal: chat keeps working, just silently.
  Future<bool> requestPermission() async {
    if (!PlatformChecks.isAndroid) return true;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return false;
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> showChat({
    required String tag,
    required String title,
    required String body,
  }) async {
    if (!_initialized) await init();
    if (!_initialized) return;
    try {
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          _chatChannelId,
          _chatChannelName,
          channelDescription: _chatChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.message,
          enableVibration: true,
          showWhen: true,
          // Stable id per chat: newer messages REPLACE the older
          // notification of the same conversation instead of stacking.
          tag: tag,
        ),
      );
      // Android notification ids must be 32-bit ints — a stable per-tag id
      // derived from the tag string keeps the replace-per-chat semantics.
      await _plugin.show(tag.hashCode & 0x7fffffff, title, body, details,
          payload: tag);
    } catch (_) {
      // Never let a notification failure break the chat ingest path.
    }
  }

  @override
  Future<void> cancelAllChat() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {
      // Best-effort.
    }
  }

  void _onResponse(NotificationResponse response) {
    // Tapping the notification launches / resumes the activity by default
    // (payload carries the chat tag for future deep-link routing).
    debugPrint('notification tapped: ${response.payload}');
  }
}

/// Platform guards kept separate so tests can run the service logic
/// without a real platform.
class PlatformChecks {
  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}
