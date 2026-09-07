/// Chat keep-alive foreground service (V3.0.5 — user-reported bug 1:
/// «не приходят оповещения о новых сообщениях если абонент вышел из
/// приложения»).
///
/// Problem: when the user leaves the app (home screen / app switcher), the
/// Android process may be frozen or killed — the UDP socket and the chat
/// ingest loop die with the UI engine, so incoming messages produce no
/// notification (and, once the process is killed, are missed entirely).
///
/// Solution: a lightweight Android foreground service started at app launch
/// keeps the process (and therefore the main Dart isolate with its UDP
/// socket) alive while the app is backgrounded. Messages keep arriving and
/// ChatSyncService surfaces them as system notifications.
///
/// Swipe-away survival: the service is declared with `stopWithTask=false`,
/// so the PROCESS survives the user swiping the app away even though the
/// UI engine is destroyed. The task isolate (ChatKeepAliveTask) then takes
/// over: it watches the main-isolate heartbeat and, when the pings stop,
/// binds its own UDP socket and shows notifications directly. Missed
/// messages are healed by the history sync when the app is reopened.
///
/// This class is the UI-isolate side: it initializes the plugin, starts /
/// updates the service and streams a small snapshot (chat labels + user
/// names) to the task isolate so IT can build notification texts without
/// touching the Sembast store (two isolates must never open the same
/// database — local-first safety rule).
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'package:pokatuha/domain/repositories/event_repository.dart';
import 'package:pokatuha/domain/repositories/group_repository.dart';
import 'package:pokatuha/domain/repositories/user_repository.dart';
import 'package:pokatuha/domain/services/chat_keep_alive_task.dart';
import 'package:pokatuha/domain/services/relay_codec.dart';

/// How often the UI isolate proves it is alive to the task isolate.
const int kKeepAlivePingIntervalMs = 3000;

/// Without a ping for this long the task isolate assumes the UI engine is
/// dead (swipe-away) and takes over message notification. Must be greater
/// than the ping interval with a comfortable margin (GC pauses, Doze
/// throttling of timers while the app is backgrounded).
const Duration kKeepAliveStaleAfter = Duration(seconds: 10);

/// Maximum snapshot entries sent per ping — guards memory on huge stores.
const int kKeepAliveSnapshotCap = 300;

/// Pure decision logic for the [ChatKeepAliveTask] — unit-testable without
/// sockets or the plugin.
class KeepAliveArbiter {
  KeepAliveArbiter({this.staleAfter = kKeepAliveStaleAfter});

  final Duration staleAfter;

  DateTime? _lastPingAt;

  /// The UI isolate proved it is alive at [at].
  void onPing(DateTime at) => _lastPingAt = at;

  /// True when no ping arrived within [staleAfter] — the task isolate
  /// should bind the UDP socket and start notifying.
  bool shouldActivate(DateTime now) {
    final last = _lastPingAt;
    return last == null || now.difference(last) > staleAfter;
  }
}

class ChatKeepAliveService {
  ChatKeepAliveService({
    required GroupRepository groupRepository,
    required EventRepository eventRepository,
    required UserRepository userRepository,
  })  : _groups = groupRepository,
        _events = eventRepository,
        _users = userRepository;

  final GroupRepository _groups;
  final EventRepository _events;
  final UserRepository _users;

  Timer? _pingTimer;
  String _title = 'Pokatuha';
  String _body = '';

  /// Whether the foreground service has been started by this service.
  bool _startedByUs = false;

  /// Local guard for the plugin's one-time init (its own flag is
  /// library-private).
  static bool _fgInitialized = false;

  /// Starts (or re-attaches to) the foreground service and the heartbeat.
  /// Called once from the widget layer when localized strings are
  /// available. Idempotent.
  Future<void> ensureStarted({
    required String title,
    required String body,
  }) async {
    _title = title;
    _body = body;
    _startPingTimer();
    try {
      if (await FlutterForegroundTask.isRunningService) {
        // Already running (hot restart, GPS sharing, app relaunch over a
        // surviving service) — just keep the notification up to date.
        await FlutterForegroundTask.updateService(
          notificationTitle: title,
          notificationText: body,
        );
        _startedByUs = true;
        return;
      }
      _ensureInit();
      await FlutterForegroundTask.startService(
        notificationTitle: title,
        notificationText: body,
        callback: chatKeepAliveCallback,
      );
      _startedByUs = true;
    } catch (_) {
      // A failed start (unsupported platform, OEM restriction) must never
      // block app startup — chat keeps working in the foreground.
      _startedByUs = false;
    }
  }

  void _ensureInit() {
    if (_fgInitialized) return;
    _fgInitialized = true;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'pokatuha_foreground_service',
        channelName: 'Pokatuha',
        channelDescription:
            'Keeps Pokatuha receiving messages in the background',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        showBadge: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction:
            ForegroundTaskEventAction.repeat(kKeepAlivePingIntervalMs),
        allowWifiLock: true,
      ),
    );
  }

  void _startPingTimer() {
    if (_pingTimer != null) return;
    _pingTimer = Timer.periodic(
      const Duration(milliseconds: kKeepAlivePingIntervalMs),
      (_) => _sendPing(),
    );
  }

  /// Sends one heartbeat with the display-name snapshots. The task isolate
  /// has no access to the database (single-isolate rule), so the UI isolate
  /// ships the labels with every ping — a few hundred short strings is
  /// negligible IPC traffic for a 3 s cadence.
  Future<void> _sendPing() async {
    try {
      final groups = <String, String>{};
      final routes = <Map<String, String>>[];
      for (final g in await _groups.all()) {
        if (groups.length >= kKeepAliveSnapshotCap) break;
        groups[g.id] = g.name;
        final code = g.inviteCode;
        if (code != null && code.trim().isNotEmpty) {
          routes.add({'gid': g.id, 'code': code});
        }
      }
      final labels = <String, String>{};
      for (final e in await _events.all()) {
        if (labels.length >= kKeepAliveSnapshotCap) break;
        final groupName = groups[e.groupId];
        labels[e.id] = (groupName == null || groupName.isEmpty)
            ? e.title
            : '$groupName · ${e.title}';
      }
      final users = <String, String>{};
      for (final u in await _users.knownUsers()) {
        if (users.length >= kKeepAliveSnapshotCap) break;
        users[u.id] = u.displayName;
      }
      // Relay topics for the task's standby subscriptions (V3.0.5 bug 2).
      final topics = <Map<String, String>>[];
      for (final route in routes) {
        topics.add({
          'gid': route['gid']!,
          'code': route['code']!,
          'topic': await topicForInviteCode(route['code']!),
        });
      }
      FlutterForegroundTask.sendDataToTask(<String, dynamic>{
        'cmd': 'ping',
        'labels': labels,
        'users': users,
        'topics': topics,
      });
    } catch (_) {
      // Snapshot failures are non-fatal — the task falls back to a
      // generic title / body.
    }
  }

  /// ForegroundLocationService hands the notification text back to the
  /// chat keep-alive when GPS sharing ends (the service itself keeps
  /// running — stopping it would kill background message delivery).
  Future<void> revertNotification() async {
    try {
      if (!await FlutterForegroundTask.isRunningService) return;
      await FlutterForegroundTask.updateService(
        notificationTitle: _title,
        notificationText: _body,
      );
    } catch (_) {
      // Best-effort.
    }
  }

  /// Stops the service and the heartbeat. Only used in tests / explicit
  /// teardown — the production service runs for the whole session.
  Future<void> stop() async {
    _pingTimer?.cancel();
    _pingTimer = null;
    _startedByUs = false;
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (_) {
      // Best-effort.
    }
  }

  /// Visible for tests.
  @visibleForTesting
  bool get pingTimerActiveForTest => _pingTimer != null;

  /// Visible for tests.
  @visibleForTesting
  bool get startedByUsForTest => _startedByUs;
}
