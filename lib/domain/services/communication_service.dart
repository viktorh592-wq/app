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

enum RealtimeType { gps, chat, poll, vote, presence, stage, arrival }

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
