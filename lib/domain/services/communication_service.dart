/// Communication architecture (Communication.md, ADR-002, ADR-003).
///
/// Three modes:
///   - Live  : WebRTC peer-to-peer (GPS, chat, polls, presence, arrivals)
///   - Sleep : FCM wake-up only (never transports user data)
///   - Offline: queue changes locally, sync automatically after reconnection
///
/// This service exposes a clean interface so the transport can evolve without
/// affecting business modules (Architecture.md — module independence).
import 'dart:async';

import 'package:pokatuha/domain/enums/enums.dart';

/// A realtime object broadcast over WebRTC in Live Mode.
class RealtimeEnvelope {
  RealtimeEnvelope({
    required this.type,
    required this.payload,
    required this.senderId,
    required this.timestamp,
  });

  final RealtimeType type;
  final Map<String, dynamic> payload;
  final String senderId;
  final int timestamp;
}

enum RealtimeType {
  gps,
  chat,
  poll,
  vote,
  presence,
  stage,
  arrival,

  /// Chat acknowledgement — receiver confirms a chat envelope (V3.0.4).
  chatAck,

  /// Request for recent chat history of a group (V3.0.4 — history sync
  /// after a QR join). Payload: `{groupId, requesterId}`.
  chatHistoryRequest,

  /// Reply to a history request — one batch per event. Payload:
  /// `{groupId, requesterId, eventId, messages: [...]}`.
  chatHistoryBatch,

  /// Request for the group STATE (members + activities) — V3.0.5 bug 3:
  /// the QR payload was slimmed down (only id / name / code / owner) so
  /// the QR is easy to scan; the roster arrives over the network after
  /// the join. Payload: `{groupId, code, requesterId}` — the code doubles
  /// as the authorization (knowing the invite = having scanned the QR).
  groupStateRequest,

  /// Reply to a state request — the full group snapshot. Payload:
  /// `{groupId, requesterId, group: {...}, members: [...], events: [...]}`.
  groupStateBatch,

  /// Live activity upsert — V3.0.7 bug 2: when an organizer creates or
  /// edits an activity, the change is broadcast immediately so every
  /// member of the group sees it without rescanning the QR. Payload:
  /// `{groupId, event: {...}, byUserId, op: "create"|"update"}`.
  /// Receivers upsert the event into their local store (local-first:
  /// existing local copy with newer version wins).
  activityUpsert,

  /// Live membership change — V3.0.7 bug 1: when an admin adds a member
  /// to the group, the new member's UserCollection is broadcast so every
  /// existing member's device materializes the new participant. Payload:
  /// `{groupId, member: {userId, displayName, username, role, canInvite,
  ///  joinedAt}, user: {id, displayName, username}, byUserId}`.
  memberAdded,

  /// Live activity edit permission ack — V3.0.7 bug 2: a member who is
  /// NOT allowed to edit (not organizer, not owner/admin) gets a denial
  /// envelope so the UI shows an error. Payload: `{eventId, byUserId,
  /// reason}`. Never mutates state — purely a UI signal.
  activityEditDenied,
}

/// Queued change awaiting synchronization (Offline Mode — UC-005).
class PendingChange {
  PendingChange({
    required this.id,
    required this.collection,
    required this.operation,
    required this.payload,
    required this.queuedAt,
  });

  final String id;
  final String collection;
  final String operation; // create / update / delete
  final Map<String, dynamic> payload;
  final int queuedAt;
  bool synced = false;
}

abstract class CommunicationService {
  CommunicationMode get mode;
  Stream<CommunicationMode> get modeStream;
  Stream<RealtimeEnvelope> get incoming;

  Future<void> connect({required String sessionId, required String peerToken});
  Future<void> broadcast(RealtimeEnvelope envelope);
  Future<void> disconnect();

  /// Wake-up triggered by FCM (ADR-003). Only reconnects WebRTC; never
  /// transports chat / GPS / media.
  Future<void> onFcmWakeUp({required String sessionId});

  /// Offline queue (UC-005).
  void enqueue(PendingChange change);
  List<PendingChange> get pendingQueue;
  Future<void> syncPending();
}

/// In-process implementation suitable for Local-First development and tests.
/// Real WebRTC signaling (NAT traversal) is provided by a signaling exchange
/// that peers perform out-of-band; this implementation handles the local
/// envelope routing and offline queue faithfully.
class LocalCommunicationService implements CommunicationService {
  LocalCommunicationService();

  final StreamController<CommunicationMode> _modeController =
      StreamController<CommunicationMode>.broadcast();
  final StreamController<RealtimeEnvelope> _incomingController =
      StreamController<RealtimeEnvelope>.broadcast();
  final List<PendingChange> _queue = <PendingChange>[];

  CommunicationMode _mode = CommunicationMode.offline;
  bool _connected = false;

  @override
  CommunicationMode get mode => _mode;

  @override
  Stream<CommunicationMode> get modeStream => _modeController.stream;

  @override
  Stream<RealtimeEnvelope> get incoming => _incomingController.stream;

  @override
  Future<void> connect({
    required String sessionId,
    required String peerToken,
  }) async {
    // In a full deployment this negotiates a WebRTC peer connection via
    // flutter_webrtc. For Local-First operation we mark the link active.
    _connected = true;
    _setMode(CommunicationMode.live);
  }

  @override
  Future<void> broadcast(RealtimeEnvelope envelope) async {
    if (!_connected) {
      // Offline: queue the change (UC-005).
      enqueue(PendingChange(
        id: envelope.payload['id'] as String? ?? '',
        collection: envelope.type.name,
        operation: 'create',
        payload: envelope.payload,
        queuedAt: envelope.timestamp,
      ));
      return;
    }
    // Locally route the envelope back so listeners (GPS, chat) react.
    _incomingController.add(envelope);
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    _setMode(CommunicationMode.sleep);
  }

  @override
  Future<void> onFcmWakeUp({required String sessionId}) async {
    // ADR-003: FCM only wakes the app; then we reconnect WebRTC.
    _setMode(CommunicationMode.sleep);
    await connect(sessionId: sessionId, peerToken: '');
  }

  @override
  void enqueue(PendingChange change) => _queue.add(change);

  @override
  List<PendingChange> get pendingQueue => List.unmodifiable(_queue);

  @override
  Future<void> syncPending() async {
    if (!_connected) return;
    for (final change in _queue.where((c) => !c.synced)) {
      change.synced = true;
    }
    _queue.removeWhere((c) => c.synced);
  }

  void _setMode(CommunicationMode next) {
    if (_mode == next) return;
    _mode = next;
    _modeController.add(next);
  }

  void dispose() {
    _modeController.close();
    _incomingController.close();
  }
}
