/// Tests for the P2P chat wiring added in V3.0.4 (bug 1 — chat does not
/// work between devices).
///
/// Two fake devices are created on top of a minimal in-memory broadcast hub
/// (stands in for the UDP transport) plus in-memory Sembast databases. The
/// suite exercises the exact flows the user reported:
///   * a message sent on device A appears in device B's store;
///   * the sender's bubble flips to delivered on ack;
///   * a history request returns the last 50 messages and they are ingested.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:pokatuha/database/collections/message_collection.dart';
import 'package:pokatuha/database/collections/user_collection.dart';
import 'package:pokatuha/database/database.dart';
import 'package:pokatuha/domain/enums/enums.dart';
import 'package:pokatuha/domain/repositories/event_repository.dart';
import 'package:pokatuha/domain/repositories/group_member_repository.dart';
import 'package:pokatuha/domain/repositories/message_repository.dart';
import 'package:pokatuha/domain/repositories/user_repository.dart';
import 'package:pokatuha/domain/services/auth_service.dart';
import 'package:pokatuha/domain/services/chat_sync_service.dart';
import 'package:pokatuha/domain/services/communication_service.dart';

/// Minimal in-memory transport: broadcasts fan out to every OTHER linked
/// hub (like two devices on one Wi-Fi). Loopback is included, mirroring the
/// real LocalNetworkCommunicationService behaviour.
class _Hub implements CommunicationService {
  final List<_Hub> _peers = <_Hub>[];
  final _controller = StreamController<RealtimeEnvelope>.broadcast();
  final List<RealtimeEnvelope> sent = <RealtimeEnvelope>[];

  void link(_Hub other) {
    _peers.add(other);
    other._peers.add(this);
  }

  @override
  Stream<RealtimeEnvelope> get incoming => _controller.stream;

  @override
  Future<void> broadcast(RealtimeEnvelope envelope) async {
    sent.add(envelope);
    // Local loopback (own envelope reaches own listeners) ...
    _controller.add(envelope);
    // ... and fan-out to peers on the same "network".
    for (final peer in _peers) {
      peer._controller.add(envelope);
    }
  }

  // Unused by ChatSyncService / MessageRepository under test.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// AuthService stub with a fixed current user (avoids repository setup).
class _StubAuth implements AuthService {
  _StubAuth(this.user);
  final UserCollection? user;

  @override
  UserCollection? get current => user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Device {
  _Device._(
    this.userId,
    this.hub,
    this.db,
    this.auth,
  );

  static Future<_Device> create(String userId) async {
    final db = await DatabaseService.memory();
    final hub = _Hub();
    final auth = _StubAuth(UserCollection()..id = userId);
    return _Device._(userId, hub, db, auth);
  }

  final String userId;
  final _Hub hub;
  final DatabaseService db;
  final _StubAuth auth;

  late final MessageRepository messages =
      MessageRepository(db, transport: hub);
  late final EventRepository events = EventRepository(db);
  late final GroupMemberRepository members = GroupMemberRepository(db);
  late final UserRepository users = UserRepository(db);
  late final ChatSyncService sync = ChatSyncService(
    transport: hub,
    messageRepository: messages,
    eventRepository: events,
    memberRepository: members,
    authService: auth,
  );

  Future<void> dispose() => db.close();
}

void main() {
  late _Device alice; // has the group + history (the «owner» device)
  late _Device bob; // just scanned the QR (the «joiner» device)
  const eventId = 'event-1';
  const groupId = 'group-1';

  setUp(() async {
    alice = await _Device.create('alice');
    bob = await _Device.create('bob');
    alice.hub.link(bob.hub);
    alice.sync.start();
    bob.sync.start();
  });

  tearDown(() async {
    await alice.dispose();
    await bob.dispose();
  });

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 60));

  test('live message: sent on A arrives in B store, ack flips delivery state',
      () async {
    final sent = await alice.messages.sendText(
      eventId: eventId,
      authorId: 'alice',
      text: 'Привет с другого устройства',
    );
    await settle();

    // Bob's local store now contains Alice's message (the core V3.0.4 fix).
    final bobMessages = await bob.messages.byEvent(eventId);
    expect(bobMessages, hasLength(1));
    expect(bobMessages.first.id, sent.id);
    expect(bobMessages.first.text, 'Привет с другого устройства');
    expect(bobMessages.first.authorId, 'alice');
    expect(bobMessages.first.deliveryState, DeliveryState.delivered.name);

    // Alice's own copy advanced queued -> sending -> delivered via ack.
    final aliceCopy = await alice.messages.getById(sent.id);
    expect(aliceCopy!.deliveryState, DeliveryState.delivered.name);
  });

  test('duplicate envelopes are ingested exactly once', () async {
    final sent = await alice.messages.sendText(
      eventId: eventId,
      authorId: 'alice',
      text: 'dup',
    );
    await settle();

    // Re-inject the same payload (duplicate UDP datagram) on Bob's repo.
    final deliveredAgain = await bob.messages.ingestIncoming(
      sent.toMap(),
      deliveryState: DeliveryState.delivered.name,
    );
    expect(deliveredAgain, isFalse,
        reason: 'duplicate (same id+version, no state change) must be ignored');
    expect(await bob.messages.byEvent(eventId), hasLength(1));
  });

  test('history request returns last 50 messages and they are ingested',
      () async {
    // Seed 60 messages on Alice's device.
    for (var i = 1; i <= 60; i++) {
      await alice.messages.sendText(
        eventId: eventId,
        authorId: 'alice',
        text: 'msg-$i',
      );
    }
    // Make Bob a member of the group on Alice's device (privacy filter).
    await alice.members.addMember(
      groupId: groupId,
      userId: 'bob',
      role: GroupRole.member.name,
      canInvite: false,
      addedBy: 'alice',
    );

    // Bob asks for the group history (as after a QR join).
    await bob.sync.requestHistory(groupId);
    await settle();

    final bobMessages = await bob.messages.byEvent(eventId);
    expect(bobMessages, hasLength(50), reason: 'history window is 50');
    expect(bobMessages.first.text, 'msg-11',
        reason: 'the 50 MOST RECENT messages are served');
    expect(bobMessages.last.text, 'msg-60');
  });

  test('history request from a NON-member is not answered (privacy filter)',
      () async {
    await alice.messages.sendText(
      eventId: eventId,
      authorId: 'alice',
      text: 'secret',
    );
    // Bob is NOT in the group roster on Alice's device.
    await bob.sync.requestHistory(groupId);
    await settle();
    expect(await bob.messages.byEvent(eventId), isEmpty);
  });

  test('incoming ingest never re-broadcasts (loop safety)', () async {
    final sentBefore = bob.hub.sent.length;
    final stored = await bob.messages.ingestIncoming(
      MessageCollection()
        ..id = 'x-1'
        ..createdAt = 1
        ..updatedAt = 1
        ..version = 1
        ..eventId = eventId
        ..authorId = 'alice'
        ..kind = MessageKind.text.name
        ..text = 'from wire'
        ..deliveryState = DeliveryState.delivered.name
        ..createdBy = 'alice'
        .toMap(),
    );
    expect(stored, isTrue);
    expect(bob.hub.sent.length, sentBefore,
        reason: 'ingest is a sink — it must not fan out envelopes');
  });

  test('second requestHistory inside the cooldown is rate-limited', () async {
    await alice.members.addMember(
      groupId: groupId,
      userId: 'bob',
      role: GroupRole.member.name,
      canInvite: false,
      addedBy: 'alice',
    );
    await alice.messages.sendText(
      eventId: eventId,
      authorId: 'alice',
      text: 'one',
    );
    await bob.sync.requestHistory(groupId);
    await bob.sync.requestHistory(groupId); // cooldown — must be a no-op
    await settle();

    // Bob broadcast exactly ONE history request, Alice answered with
    // exactly ONE batch for the single event of the group.
    final requests = bob.hub.sent
        .where((e) => e.type == RealtimeType.chatHistoryRequest)
        .length;
    final batches = alice.hub.sent
        .where((e) => e.type == RealtimeType.chatHistoryBatch)
        .length;
    expect(requests, 1);
    expect(batches, 1);
    expect(await bob.messages.byEvent(eventId), hasLength(1));
  });
}
