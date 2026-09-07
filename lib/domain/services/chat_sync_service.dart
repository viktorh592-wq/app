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
import 'package:pokatuha/database/collections/event_collection.dart';
import 'package:pokatuha/database/collections/group_collection.dart';
import 'package:pokatuha/database/collections/message_collection.dart';
import 'package:pokatuha/database/collections/user_collection.dart';
import 'package:pokatuha/domain/enums/enums.dart';
import 'package:pokatuha/domain/repositories/event_repository.dart';
import 'package:pokatuha/domain/repositories/group_member_repository.dart';
import 'package:pokatuha/domain/repositories/group_repository.dart';
import 'package:pokatuha/domain/repositories/message_repository.dart';
import 'package:pokatuha/domain/repositories/participant_repository.dart';
import 'package:pokatuha/domain/repositories/user_repository.dart';
import 'package:pokatuha/domain/services/auth_service.dart';
import 'package:pokatuha/domain/services/communication_service.dart';
import 'package:pokatuha/domain/services/system_notification_service.dart';

/// How many recent messages per event are served for a history request.
const int kHistoryBatchSize = 50;

/// How many activities are served in one groupState batch (V3.0.5 bug 3).
const int kGroupStateEventsCap = 50;

/// Minimum delay between two history requests for the same group —
/// protects against duplicated QR scans flooding peers.
const Duration kHistoryRequestCooldown = Duration(seconds: 5);

/// First characters of an id used for placeholder display names —
/// bounded by the actual length (ids in tests may be shorter than 6).
String _shortId(String id) =>
    id.length <= 6 ? id : id.substring(0, 6);

class ChatSyncService {
  ChatSyncService({
    required CommunicationService transport,
    required MessageRepository messageRepository,
    required EventRepository eventRepository,
    required GroupMemberRepository memberRepository,
    required AuthService authService,
    ChatNotifications? notifications,
    GroupRepository? groupRepository,
    UserRepository? userRepository,
    ParticipantRepository? participantRepository,
    bool Function()? isAppInBackground,
  })  : _transport = transport,
        _messages = messageRepository,
        _events = eventRepository,
        _members = memberRepository,
        _auth = authService,
        _notifications = notifications,
        _groups = groupRepository,
        _users = userRepository,
        _participants = participantRepository,
        _isAppInBackground = isAppInBackground;

  final CommunicationService _transport;
  final MessageRepository _messages;
  final EventRepository _events;
  final GroupMemberRepository _members;
  final AuthService _auth;

  /// V3.0.5 (bug 1) — optional system-notification sink. When provided and
  /// the app is backgrounded, a fresh inbound message is surfaced in the
  /// Android status bar.
  final ChatNotifications? _notifications;
  final GroupRepository? _groups;
  final UserRepository? _users;
  final ParticipantRepository? _participants;
  final bool Function()? _isAppInBackground;

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
        case RealtimeType.groupStateRequest:
          await _onGroupStateRequest(envelope);
        case RealtimeType.groupStateBatch:
          await _onGroupStateBatch(envelope);
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
    // V3.0.5 (bug 1) — surface the fresh message when the app is not in
    // the foreground. Best-effort: never breaks the ingest/ack path.
    await _notifyIncoming(envelope.payload);
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
  // System notifications (V3.0.5 — bug 1)
  // ---------------------------------------------------------------------

  /// Shows a status-bar notification for a freshly ingested chat message
  /// when the app is NOT in the foreground. Resolves the display names
  /// best-effort from the local stores — missing data degrades to a
  /// generic title / body but never throws.
  Future<void> _notifyIncoming(Map<String, dynamic> payload) async {
    final notifications = _notifications;
    if (notifications == null) return;
    final inBackground = _isAppInBackground?.call() ?? false;
    if (!inBackground) return;
    try {
      final eventId = payload['eventId'] as String? ?? '';
      final authorId = payload['authorId'] as String? ?? '';
      final text = (payload['text'] as String? ?? '').trim();
      if (eventId.isEmpty) return;

      final authorName = authorId.isEmpty
          ? ''
          : (await _users?.getById(authorId))?.displayName ?? '';

      // Event → group → «Group · Event» title (falls back gracefully).
      String title = 'Pokatuha';
      String tag = eventId;
      final event = await _events.getById(eventId);
      if (event != null) {
        final eventGroupId = event.groupId;
        if (eventGroupId != null && eventGroupId.isNotEmpty) {
          tag = eventGroupId;
        }
        final group = (eventGroupId == null || eventGroupId.isEmpty)
            ? null
            : (await _groups?.getById(eventGroupId));
        final groupName = group?.name ?? '';
        title = groupName.isEmpty || groupName == event.title
            ? event.title
            : '$groupName · ${event.title}';
      }

      final body = text.isEmpty
          ? authorName
          : (authorName.isEmpty ? text : '$authorName: $text');
      if (body.isEmpty) return;
      await notifications.showChat(tag: tag, title: title, body: body);
    } catch (_) {
      // A notification failure must never break the ingest / ack path.
    }
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

  // ---------------------------------------------------------------------
  // Group state sync (V3.0.5 — bug 3)
  // ---------------------------------------------------------------------

  /// Asks peers for the full group state (members + activities) right
  /// after a slim-payload QR join. The invite code doubles as the
  /// authorization — only devices that recognize the code answer.
  /// Rate-limited like [requestHistory].
  Future<void> requestGroupState(String groupId, String code) async {
    final me = _me;
    if (me == null || groupId.isEmpty || code.trim().isEmpty) return;
    final now = DateTime.now();
    final last = _lastHistoryRequestAt[groupId];
    if (last != null && now.difference(last) < kHistoryRequestCooldown) {
      return;
    }
    _lastHistoryRequestAt[groupId] = now;
    await _transport.broadcast(RealtimeEnvelope(
      type: RealtimeType.groupStateRequest,
      payload: <String, dynamic>{
        'groupId': groupId,
        'code': code,
        'requesterId': me,
      },
      senderId: me,
      timestamp: Timestamps.nowUtc(),
    ));
  }

  /// Answers a state request ONLY when the requester proves they hold the
  /// invite code (the same secret the QR carries). Replies with a single
  /// batch: group doc + members + activities (capped).
  Future<void> _onGroupStateRequest(RealtimeEnvelope envelope) async {
    final me = _me;
    if (me == null || envelope.senderId == me) return;
    final groupId = envelope.payload['groupId'] as String? ?? '';
    final code = envelope.payload['code'] as String? ?? '';
    final requesterId = envelope.payload['requesterId'] as String? ?? '';
    if (groupId.isEmpty || code.trim().isEmpty || requesterId.isEmpty) {
      return;
    }
    final groups = _groups;
    if (groups == null) return;
    final group = await groups.getById(groupId);
    if (group == null) return;
    // Authorization: the requester must present the group's invite code.
    // NOTE: membership is deliberately NOT required — a device that just
    // scanned the QR is not yet in anyone's roster; holding the invite
    // code (the same secret the QR carries) IS the authorization.
    final localCode = group.inviteCode?.trim().toUpperCase() ?? '';
    if (localCode.isEmpty || localCode != code.trim().toUpperCase()) {
      return;
    }

    final members = await _members.byGroup(groupId);
    final memberPayloads = <Map<String, dynamic>>[];
    for (final m in members) {
      final u = await _users?.getById(m.userId);
      memberPayloads.add({
        'userId': m.userId,
        'displayName': u?.displayName ?? '',
        'username': u?.username ?? '',
        'role': m.role,
        'canInvite': m.canInvite,
        'joinedAt': m.joinedAt,
      });
    }

    final allEvents = await _events.byGroup(groupId);
    final eventPayloads = <Map<String, dynamic>>[];
    var count = 0;
    for (final e in allEvents) {
      if (count >= kGroupStateEventsCap) break;
      count++;
      eventPayloads.add(e.toMap());
    }

    await _transport.broadcast(RealtimeEnvelope(
      type: RealtimeType.groupStateBatch,
      payload: <String, dynamic>{
        'groupId': groupId,
        'requesterId': requesterId,
        'group': group.toMap(),
        'members': memberPayloads,
        'events': eventPayloads,
      },
      senderId: me,
      timestamp: Timestamps.nowUtc(),
    ));
  }

  /// Ingests a state batch that answers OUR request: materializes missing
  /// users / members / activities. Never overwrites existing local
  /// records (local-first: local state wins).
  Future<void> _onGroupStateBatch(RealtimeEnvelope envelope) async {
    final me = _me;
    if (me == null || envelope.senderId == me) return;
    final requesterId = envelope.payload['requesterId'] as String?;
    if (requesterId != me) return;
    final groups = _groups;
    if (groups == null) return;

    // Materialize the group when it is somehow missing.
    final rawGroup = envelope.payload['group'];
    String groupId =
        envelope.payload['groupId'] as String? ?? '';
    if (rawGroup is Map) {
      final g = GroupCollection.fromMap(Map<String, dynamic>.from(rawGroup));
      if (g.id.isNotEmpty) groupId = g.id;
      final existing = await groups.getById(g.id);
      if (existing == null) {
        await groups.create(g);
      }
    }
    if (groupId.isEmpty) return;

    // Materialize users + memberships.
    final rawMembers = envelope.payload['members'];
    if (rawMembers is List) {
      for (final raw in rawMembers) {
        if (raw is! Map) continue;
        final m = Map<String, dynamic>.from(raw);
        final userId = m['userId'] as String? ?? '';
        if (userId.isEmpty || userId == me) continue;
        final users = _users;
        if (users != null) {
          final existingUser = await users.getById(userId);
          if (existingUser == null) {
            final now = Timestamps.nowUtc();
            final displayName = m['displayName'] as String? ?? '';
            await users.upsertKnown(UserCollection()
              ..id = userId
              ..createdAt = now
              ..updatedAt = now
              ..version = 1
              ..isDeleted = false
              ..displayName = displayName.isEmpty
                  ? 'User ${_shortId(userId)}'
                  : displayName
              ..username = (m['username'] as String?)?.isNotEmpty == true
                  ? m['username'] as String
                  : (displayName.isEmpty
                      ? 'user_${_shortId(userId)}'
                      : displayName)
              ..profileVisible = true);
          }
        }
        try {
          await _members.addMember(
            groupId: groupId,
            userId: userId,
            role: m['role'] as String? ?? 'member',
            canInvite: m['canInvite'] as bool? ?? false,
            addedBy: me,
            joinedAt: (m['joinedAt'] as num?)?.toInt(),
          );
        } catch (_) {
          // Duplicate membership — idempotent ingest.
        }
      }
    }

    // Materialize missing activities (+ organizer participants).
    final rawEvents = envelope.payload['events'];
    if (rawEvents is List) {
      for (final raw in rawEvents) {
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        final eventId = map['id'] as String? ?? '';
        if (eventId.isEmpty) continue;
        final existing = await _events.getById(eventId);
        if (existing != null) continue;
        final event = EventCollection.fromMap(map)
          ..id = eventId
          ..groupId = groupId;
        await _events.upsertFromInvitation(event);
        _messages.notifyChanged(eventId);
        // Organizer becomes an accepted participant (parity with the QR
        // accept path).
        final organizerId = event.organizerId;
        final participants = _participants;
        if (organizerId.isNotEmpty && participants != null) {
          try {
            final existingP = await participants.byEventAndUser(
              eventId,
              organizerId,
            );
            if (existingP == null) {
              await participants.invite(
                eventId: eventId,
                userId: organizerId,
                role: ParticipantRole.organizer.name,
                byUserId: organizerId,
              );
              final organizerP =
                  await participants.byEventAndUser(eventId, organizerId);
              if (organizerP != null) {
                await participants.setStatus(
                    organizerP, ParticipantStatus.accepted);
              }
            }
          } catch (_) {
            // Best-effort parity — never fail the batch ingest.
          }
        }
      }
    }
  }
}
