/// Chat synchronisation orchestrator (V3.0.4 — user-reported bug 1).
///
/// Responsibilities:
///   * Persist incoming `chat` envelopes from the transport into the local
///     Sembast store (de-duplicated, idempotent) and acknowledge them;
///   * Acknowledge outgoing messages when peers confirm delivery;
///   * Answer `chatHistoryRequest` envelopes with the most recent messages
///     per event of the requested group (bounded batch, one datagram per
///     event);
///   * Ingest `chatHistoryBatch` envelopes after this device joins a group
///     via QR so the chat shows the recent history immediately.
///
/// Loop safety: ingest paths never re-broadcast, acks are only sent for
/// `chat` envelopes, batches only for requests — so envelopes can never
/// bounce back and forth between peers. Self-originated envelopes are
/// already filtered by the transport (origin id).
///
/// Privacy (ADR-008): history requests are answered only when the
/// requester is a member of the requested group on THIS device. UDP on a
/// LAN is inherently unauthenticated — this is a courtesy filter, not a
/// security boundary; the transport stays confined to the local network.
library;

import 'dart:async';

import 'package:pokatuha/core/utils/timestamps.dart';
import 'package:pokatuha/domain/enums/enums.dart';
import 'package:pokatuha/domain/repositories/event_repository.dart';
import 'package:pokatuha/domain/repositories/group_member_repository.dart';
import 'package:pokatuha/domain/repositories/message_repository.dart';
import 'package:pokatuha/domain/services/auth_service.dart';
import 'package:pokatuha/domain/services/communication_service.dart';

/// How many recent messages per event are served for a history request.
const int kHistoryBatchSize = 50;

/// Minimum delay between two history requests for the same group —
/// protects against duplicated QR scans flooding peers.
const Duration kHistoryRequestCooldown = Duration(seconds: 5);

class ChatSyncService {
  ChatSyncService({
    required CommunicationService transport,
    required MessageRepository messageRepository,
    required EventRepository eventRepository,
    required GroupMemberRepository memberRepository,
    required AuthService authService,
  })  : _transport = transport,
        _messages = messageRepository,
        _events = eventRepository,
        _members = memberRepository,
        _auth = authService;

  final CommunicationService _transport;
  final MessageRepository _messages;
  final EventRepository _events;
  final GroupMemberRepository _members;
  final AuthService _auth;

  StreamSubscription<RealtimeEnvelope>? _subscription;
  final Map<String, DateTime> _lastHistoryRequestAt = <String, DateTime>{};
  bool _started = false;

  /// Current user id, or null when onboarding is not finished yet.
  String? get _me => _auth.current?.id;

  /// Wires the incoming transport stream. Safe to call multiple times.
  void start() {
    if (_started) return;
    _started = true;
    _subscription = _transport.incoming.listen(_onEnvelope);
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _started = false;
  }

  /// Broadcasts a history request for [groupId]. Called after a group was
  /// materialised / re-opened through a QR invite so this device receives
  /// the recent chat history from peers on the same network.
  Future<void> requestHistory(String groupId) async {
    final me = _me;
    if (me == null || groupId.isEmpty) return;
    final now = DateTime.now();
    final last = _lastHistoryRequestAt[groupId];
    if (last != null && now.difference(last) < kHistoryRequestCooldown) {
      return;
    }
    _lastHistoryRequestAt[groupId] = now;
    await _transport.broadcast(RealtimeEnvelope(
      type: RealtimeType.chatHistoryRequest,
      payload: <String, dynamic>{'groupId': groupId, 'requesterId': me},
      senderId: me,
      timestamp: Timestamps.nowUtc(),
    ));
  }

  Future<void> _onEnvelope(RealtimeEnvelope envelope) async {
    try {
      switch (envelope.type) {
        case RealtimeType.chat:
          await _onChatEnvelope(envelope);
        case RealtimeType.chatAck:
          await _onChatAck(envelope);
        case RealtimeType.chatHistoryRequest:
          await _onHistoryRequest(envelope);
        case RealtimeType.chatHistoryBatch:
          await _onHistoryBatch(envelope);
        default:
          break; // gps / poll / vote / presence / stage / arrival — not here
      }
    } catch (_) {
      // A malformed envelope from a foreign/older peer must never crash
      // the sync loop.
    }
  }

  // ---------------------------------------------------------------------
  // Live chat messages
  // ---------------------------------------------------------------------

  Future<void> _onChatEnvelope(RealtimeEnvelope envelope) async {
    final me = _me;
    if (me == null) return;
    // Guard against self-echo (belt & suspenders — the transport already
    // filters its own origin).
    if (envelope.senderId == me) return;
    final stored = await _messages.ingestIncoming(
      envelope.payload,
      deliveryState: DeliveryState.delivered.name,
    );
    if (!stored) return; // duplicate or older version — nothing to do
    // Acknowledge so the sender's bubble flips to `delivered`.
    final messageId = envelope.payload['id'] as String?;
    if (messageId == null || messageId.isEmpty) return;
    await _transport.broadcast(RealtimeEnvelope(
      type: RealtimeType.chatAck,
      payload: <String, dynamic>{'ackFor': messageId, 'by': me},
      senderId: me,
      timestamp: Timestamps.nowUtc(),
    ));
  }

  Future<void> _onChatAck(RealtimeEnvelope envelope) async {
    final me = _me;
    if (me == null) return;
    final messageId = envelope.payload['ackFor'] as String?;
    if (messageId == null || messageId.isEmpty) return;
    final message = await _messages.getById(messageId);
    if (message == null) return;
    // Only the AUTHOR's device flips its own outgoing bubble. The ack is
    // sent by the receiving peer (envelope.senderId), so never compare the
    // author id against the ack sender.
    if (message.authorId != me) return;
    if (message.deliveryState == DeliveryState.delivered.name) return;
    await _messages.setDeliveryState(message, DeliveryState.delivered);
    _messages.notifyChanged(message.eventId);
  }

  // ---------------------------------------------------------------------
  // History sync
  // ---------------------------------------------------------------------

  Future<void> _onHistoryRequest(RealtimeEnvelope envelope) async {
    final me = _me;
    if (me == null || envelope.senderId == me) return;
    final groupId = envelope.payload['groupId'] as String?;
    final requesterId = envelope.payload['requesterId'] as String?;
    if (groupId == null || groupId.isEmpty) return;
    if (requesterId == null || requesterId.isEmpty) return;
    // Privacy courtesy: only answer to members of the group on this device.
    final members = await _members.byGroup(groupId);
    final isMember = members.any((m) => m.userId == requesterId);
    if (!isMember) return;
    final events = await _events.byGroup(groupId);
    for (final event in events) {
      final recent = await _messages.recentByEvent(event.id, kHistoryBatchSize);
      if (recent.isEmpty) continue;
      await _transport.broadcast(RealtimeEnvelope(
        type: RealtimeType.chatHistoryBatch,
        payload: <String, dynamic>{
          'groupId': groupId,
          'requesterId': requesterId,
          'eventId': event.id,
          'messages': recent.map((m) => m.toMap()).toList(),
        },
        senderId: me,
        timestamp: Timestamps.nowUtc(),
      ));
    }
  }

  Future<void> _onHistoryBatch(RealtimeEnvelope envelope) async {
    final me = _me;
    if (me == null || envelope.senderId == me) return;
    // Only ingest batches that answer OUR requests.
    final requesterId = envelope.payload['requesterId'] as String?;
    if (requesterId != me) return;
    final rawMessages = envelope.payload['messages'];
    if (rawMessages is! List) return;
    for (final raw in rawMessages) {
      if (raw is! Map) continue;
      await _messages.ingestIncoming(
        Map<String, dynamic>.from(raw),
        deliveryState: DeliveryState.delivered.name,
      );
    }
    final eventId = envelope.payload['eventId'] as String?;
    if (eventId != null && eventId.isNotEmpty) {
      _messages.notifyChanged(eventId);
    }
  }
}
