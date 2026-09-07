/// Keep-alive task — runs inside the background engine created by
/// flutter_foreground_task (V3.0.5 — bug 1).
///
/// Lifecycle:
///   1. The service starts while the app is in the FOREGROUND (allowed on
///      every Android version). The task handler starts DORMANT: the main
///      isolate owns the UDP socket, the store and notifications.
///   2. The main isolate pings the task every 3 s with fresh display-name
///      snapshots (chat labels + user names).
///   3. When the user swipes the app away, the UI engine is destroyed but
///      the service keeps the process alive (`stopWithTask=false`). Pings
///      stop → the [KeepAliveArbiter] activates the task: it binds its own
///      UDP socket and shows system notifications for incoming chat
///      messages. It deliberately does NOT touch the Sembast store (two
///      isolates must never open the same database) — missed messages are
///      healed by the history sync when the app is reopened.
///   4. When the app is launched again, pings resume → the task closes its
///      socket and goes back to sleep.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'package:pokatuha/domain/services/chat_keep_alive_service.dart';
import 'package:pokatuha/domain/services/communication_service.dart';
import 'package:pokatuha/domain/services/local_network_communication_service.dart';
import 'package:pokatuha/domain/services/system_notification_service.dart';

/// Top-level entry point — MUST be a top-level function for the plugin to
/// reach it from the background engine.
@pragma('vm:entry-point')
void chatKeepAliveCallback() {
  FlutterForegroundTask.setTaskHandler(ChatKeepAliveTask());
}

/// Cap of remembered envelope ids in the task isolate (each datagram can
/// arrive twice: limited + directed broadcast targets).
const int kTaskMaxSeenEnvelopes = 256;

class ChatKeepAliveTask extends TaskHandler {
  ChatKeepAliveTask({KeepAliveArbiter? arbiter})
      : _arbiter = arbiter ?? KeepAliveArbiter();

  final KeepAliveArbiter _arbiter;

  /// Display-name snapshots streamed from the main isolate via pings.
  Map<String, String> _labels = const <String, String>{};
  Map<String, String> _users = const <String, String>{};

  /// Bound only while ACTIVE (UI engine dead). Null while dormant.
  RawDatagramSocket? _socket;

  /// Guards concurrent activation attempts from repeat events.
  bool _activating = false;

  final Set<String> _seenEnvelopeIds = <String>{};

  SystemNotificationService? _notifications;

  // -------------------------------------------------------------------
  // TaskHandler
  // -------------------------------------------------------------------

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Dormant — the UI isolate is alive right after startService.
  }

  @override
  void onReceiveData(Object data) {
    if (data is! Map) return;
    final map = Map<String, dynamic>.from(data);
    if (map['cmd'] != 'ping') return;
    _arbiter.onPing(DateTime.now());
    final labels = map['labels'];
    final users = map['users'];
    if (labels is Map) {
      _labels = labels.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    if (users is Map) {
      _users = users.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    if (_arbiter.shouldActivate(timestamp)) {
      unawaited(_activate());
    } else {
      // The UI engine is back — hand message handling back to it.
      _deactivate();
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    _deactivate();
  }

  // -------------------------------------------------------------------
  // Active mode — UDP receive + notifications (no DB access)
  // -------------------------------------------------------------------

  Future<void> _activate() async {
    if (_socket != null || _activating) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;
    _activating = true;
    try {
      _ensureNotifications();
      final socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        kPokatuhaUdpPort,
        reuseAddress: true,
      );
      socket.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket.receive();
          if (datagram == null) return;
          _handleDatagram(datagram);
        }
      });
      _socket = socket;
    } catch (_) {
      // Bind failures (no network yet, port taken by the UI engine during
      // a race) stay silent — the next repeat event retries activation.
      _socket = null;
    } finally {
      _activating = false;
    }
  }

  void _deactivate() {
    final socket = _socket;
    if (socket == null) return;
    _socket = null;
    try {
      socket.close();
    } catch (_) {}
    _seenEnvelopeIds.clear();
  }

  void _ensureNotifications() {
    _notifications ??= SystemNotificationService();
    final plugin = _notifications!;
    if (!plugin.isInitialized) {
      // Fire-and-forget: the first showChat() also awaits init().
      plugin.init().catchError((Object _) {});
    }
  }

  void _handleDatagram(Datagram datagram) {
    String body;
    Map<String, dynamic> raw;
    try {
      body = utf8.decode(datagram.data, allowMalformed: true);
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) return;
      raw = decoded;
    } catch (_) {
      return; // foreign traffic on this port
    }
    if ((raw['v'] as int? ?? 0) != kEnvelopeVersion) return;
    final eid = raw['eid'] as String? ?? '';
    if (eid.isEmpty) return;
    if (!_remember(eid)) return;
    final envelope = LocalNetworkCommunicationService.decodeEnvelope(
      body,
      envelopeId: eid,
      origin: raw['o'] as String? ?? '',
    );
    if (envelope == null) return;
    if (envelope.type != RealtimeType.chat) {
      return; // acks / history batches never notify
    }
    _notify(envelope.payload);
  }

  bool _remember(String eid) {
    if (_seenEnvelopeIds.contains(eid)) return false;
    while (_seenEnvelopeIds.length >= kTaskMaxSeenEnvelopes) {
      _seenEnvelopeIds.remove(_seenEnvelopeIds.first);
    }
    _seenEnvelopeIds.add(eid);
    return true;
  }

  /// Builds the notification from the chat payload + snapshots. Never
  /// touches the database.
  Future<void> _notify(Map<String, dynamic> payload) async {
    final notifications = _notifications;
    if (notifications == null) return;
    try {
      final eventId = payload['eventId'] as String? ?? '';
      final authorId = payload['authorId'] as String? ?? '';
      final text = (payload['text'] as String? ?? '').trim();
      if (eventId.isEmpty) return;
      final authorName = _users[authorId] ?? '';
      final body = text.isEmpty
          ? authorName
          : (authorName.isEmpty ? text : '$authorName: $text');
      if (body.isEmpty) return;
      await notifications.showChat(
        tag: eventId,
        title: _labels[eventId] ?? 'Pokatuha',
        body: body,
      );
    } catch (_) {
      // Notification failures must never kill the task.
    }
  }
}
