/// Tests for the V3.0.5 chat notification wiring (bug 1 — «не приходят
/// оповещения о новых сообщениях если абонент вышел из приложения»).
///
/// Reuses the two-device hub harness from chat_sync_service_test: a fresh
/// inbound message must surface a system notification when the app is
/// backgrounded — and never when the app is in the foreground, nor for
/// duplicates.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:pokatuha/database/collections/event_collection.dart';
import 'package:pokatuha/database/collections/group_collection.dart';
import 'package:pokatuha/database/collections/user_collection.dart';
import 'package:pokatuha/database/database.dart';
import 'package:pokatuha/domain/repositories/event_repository.dart';
import 'package:pokatuha/domain/repositories/group_member_repository.dart';
import 'package:pokatuha/domain/repositories/group_repository.dart';
import 'package:pokatuha/domain/repositories/message_repository.dart';
import 'package:pokatuha/domain/repositories/user_repository.dart';
import 'package:pokatuha/domain/services/auth_service.dart';
import 'package:pokatuha/domain/services/chat_keep_alive_service.dart';
import 'package:pokatuha/domain/services/chat_sync_service.dart';
import 'package:pokatuha/domain/services/communication_service.dart';
import 'package:pokatuha/domain/services/system_notification_service.dart';

/// Minimal in-memory transport (same semantics as chat_sync_service_test).
class _Hub implements CommunicationService {
  final List<_Hub> _peers = <_Hub>[];
  final _controller = StreamController<RealtimeEnvelope>.broadcast();

  void link(_Hub other) {
    _peers.add(other);
    other._peers.add(this);
  }

  @override
  Stream<RealtimeEnvelope> get incoming => _controller.stream;

  @override
  Future<void> broadcast(RealtimeEnvelope envelope) async {
    _controller.add(envelope);
    for (final peer in _peers) {
      peer._controller.add(envelope);
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubAuth implements AuthService {
  _StubAuth(this.user);
  final UserCollection? user;

  @override
  UserCollection? get current => user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Records every notification the sync layer requests.
class _FakeNotifications implements ChatNotifications {
  final List<({String tag, String title, String body})> shown =
      <({String tag, String title, String body})>[];
  int cancelAllCalls = 0;

  @override
  Future<void> showChat({
    required String tag,
    required String title,
    required String body,
  }) async {
    shown.add((tag: tag, title: title, body: body));
  }

  @override
  Future<void> cancelAllChat() async {
    cancelAllCalls++;
  }
}

class _Device {
  _Device._(this.hub, this.db);

  static Future<_Device> create(String userId) async {
    final db = await DatabaseService.memory();
    final hub = _Hub();
    return _Device._(hub, db)..auth = _StubAuth(UserCollection()..id = userId);
  }

  final _Hub hub;
  final DatabaseService db;
  late final _StubAuth auth;

  bool inBackground = true;
  final _FakeNotifications notifications = _FakeNotifications();

  late final MessageRepository messages = MessageRepository(db, transport: hub);
  late final EventRepository events = EventRepository(db);
  late final GroupMemberRepository members = GroupMemberRepository(db);
  late final GroupRepository groups = GroupRepository(db);
  late final UserRepository users = UserRepository(db);
  late final ChatSyncService sync = ChatSyncService(
    transport: hub,
    messageRepository: messages,
    eventRepository: events,
    memberRepository: members,
    authService: auth,
    notifications: notifications,
    groupRepository: groups,
    userRepository: users,
    isAppInBackground: () => inBackground,
  );

  Future<void> dispose() => db.close();
}

void main() {
  late _Device alice;
  late _Device bob;

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

  test('inbound message while backgrounded surfaces a system notification',
      () async {
    // Bob knows the group / event / author the way a QR join would have
    // materialized them.
    final group = GroupCollection()..name = 'Велоколония';
    group.ownerId = 'alice';
    final createdGroup = await bob.groups.create(group);
    final event = EventCollection()
      ..title = 'Вечерний выезд'
      ..startAt = 1725600000000
      ..groupId = createdGroup.id
      ..organizerId = 'alice';
    await bob.events.create(event);
    await bob.users.upsertKnown(UserCollection()
      ..id = 'alice'
      ..displayName = 'Алиса');

    await alice.messages.sendText(
      eventId: event.id,
      authorId: 'alice',
      text: 'Выезжаем через 10 минут',
    );
    await settle();

    expect(bob.notifications.shown, hasLength(1));
    final n = bob.notifications.shown.single;
    expect(n.tag, createdGroup.id);
    expect(n.title, 'Велоколония · Вечерний выезд');
    expect(n.body, 'Алиса: Выезжаем через 10 минут');
  });

  test('no notification while the app is in the foreground', () async {
    bob.inBackground = false;
    await alice.messages.sendText(
      eventId: 'event-1',
      authorId: 'alice',
      text: 'foreground',
    );
    await settle();
    expect(bob.notifications.shown, isEmpty);
  });

  test('duplicate delivery does not re-notify', () async {
    final sent = await alice.messages.sendText(
      eventId: 'event-1',
      authorId: 'alice',
      text: 'dup',
    );
    await settle();
    expect(bob.notifications.shown, hasLength(1));

    final again = await bob.messages.ingestIncoming(
      sent.toMap(),
      deliveryState: 'delivered',
    );
    expect(again, isFalse);
    expect(bob.notifications.shown, hasLength(1));
  });

  test('fallback title/body when the event is unknown locally', () async {
    bob.inBackground = true;
    await alice.messages.sendText(
      eventId: 'unknown-event',
      authorId: 'alice',
      text: 'hi',
    );
    await settle();
    expect(bob.notifications.shown, hasLength(1));
    final n = bob.notifications.shown.single;
    expect(n.title, 'Pokatuha');
    expect(n.body, 'hi'); // author unknown → text only
  });

  test('history batches never notify (only live chat does)', () async {
    final event = EventCollection()
      ..title = 'Ride'
      ..startAt = 1725600000000
      ..groupId = 'group-1'
      ..organizerId = 'alice';
    await alice.events.create(event);
    await alice.members.addMember(
      groupId: 'group-1',
      userId: 'bob',
      role: 'member',
      canInvite: false,
      addedBy: 'alice',
    );
    await alice.messages.sendText(
      eventId: event.id,
      authorId: 'alice',
      text: 'history item',
    );
    await settle();
    bob.notifications.shown.clear();

    // Bob asks for history — the batch ingest path must stay silent.
    await bob.sync.requestHistory('group-1');
    await settle();
    expect(bob.notifications.shown, isEmpty);
  });

  group('KeepAliveArbiter', () {
    test('activates when no ping ever arrived', () {
      final arbiter = KeepAliveArbiter();
      expect(arbiter.shouldActivate(DateTime.now()), isTrue);
    });

    test('stays dormant while pings are fresh', () {
      final arbiter = KeepAliveArbiter();
      final now = DateTime(2026, 1, 1, 12);
      arbiter.onPing(now);
      expect(arbiter.shouldActivate(now.add(const Duration(seconds: 3))),
          isFalse);
    });

    test('activates once pings go stale (UI engine dead)', () {
      final arbiter = KeepAliveArbiter();
      final now = DateTime(2026, 1, 1, 12);
      arbiter.onPing(now);
      final later = now.add(const Duration(seconds: 11));
      expect(arbiter.shouldActivate(later), isTrue);
    });
  });
}
