/// Tests for the V3.0.5 group-state sync (bug 3 — the QR payload was
/// slimmed down to the essentials, so members and activities are pulled
/// over the network right after the join) plus the slim invite payload
/// semantics in GroupService.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:pokatuha/database/collections/event_collection.dart';
import 'package:pokatuha/database/collections/group_collection.dart';
import 'package:pokatuha/database/collections/user_collection.dart';
import 'package:pokatuha/database/database.dart';
import 'package:pokatuha/domain/enums/enums.dart';
import 'package:pokatuha/domain/repositories/event_repository.dart';
import 'package:pokatuha/domain/repositories/group_member_repository.dart';
import 'package:pokatuha/domain/repositories/group_repository.dart';
import 'package:pokatuha/domain/repositories/message_repository.dart';
import 'package:pokatuha/domain/repositories/participant_repository.dart';
import 'package:pokatuha/domain/repositories/user_repository.dart';
import 'package:pokatuha/domain/services/auth_service.dart';
import 'package:pokatuha/domain/services/chat_sync_service.dart';
import 'package:pokatuha/domain/services/communication_service.dart';
import 'package:pokatuha/domain/services/group_service.dart';

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

  late final MessageRepository messages = MessageRepository(db, transport: hub);
  late final EventRepository events = EventRepository(db);
  late final GroupMemberRepository members = GroupMemberRepository(db);
  late final GroupRepository groups = GroupRepository(db);
  late final UserRepository users = UserRepository(db);
  late final ParticipantRepository participants = ParticipantRepository(db);
  late final GroupService groupService = GroupService(
    groups,
    members,
    events,
    users,
    participants,
  );
  late final ChatSyncService sync = ChatSyncService(
    transport: hub,
    messageRepository: messages,
    eventRepository: events,
    memberRepository: members,
    authService: auth,
    groupRepository: groups,
    userRepository: users,
    participantRepository: participants,
  );

  Future<void> dispose() => db.close();
}

void main() {
  late _Device alice; // owner device — holds the full state
  late _Device bob; // just scanned the slim QR

  const code = 'A1B2C3D4';

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

  test('slim invitation payload carries no members / activities', () async {
    final group = GroupCollection()..name = 'Велоколония';
    group.ownerId = 'alice';
    group.inviteCode = code;
    final created = await alice.groups.create(group);

    final payload = alice.groupService.invitationPayload(created);
    expect(payload.containsKey('members'), isFalse,
        reason: 'V3.0.5: members must NOT be embedded in the QR');
    expect(payload.containsKey('activities'), isFalse,
        reason: 'V3.0.5: activities must NOT be embedded in the QR');
    expect(payload['id'], created.id);
    expect(payload['inviteCode'], code);
  });

  test('slim payload join + groupState request materializes the full roster',
      () async {
    // --- Owner side: group + members + activities + chat history.
    final group = GroupCollection()..name = 'Велоколония';
    group.ownerId = 'alice';
    group.inviteCode = code;
    final created = await alice.groups.create(group);
    await alice.members.addMember(
      groupId: created.id,
      userId: 'alice',
      role: GroupRole.owner.name,
      canInvite: true,
      addedBy: 'alice',
    );
    await alice.users.upsertKnown(UserCollection()
      ..id = 'carol'
      ..displayName = 'Каролина');
    await alice.members.addMember(
      groupId: created.id,
      userId: 'carol',
      role: GroupRole.member.name,
      canInvite: false,
      addedBy: 'alice',
    );
    final event = EventCollection()
      ..title = 'Вечерний выезд'
      ..startAt = 1725600000000
      ..groupId = created.id
      ..organizerId = 'alice';
    await alice.events.create(event);

    // --- Joiner side: materialize the group from the SLIM payload.
    final slimPayload = alice.groupService.invitationPayload(created);
    final joined = await bob.groupService.acceptInvitation(
      user: bob.auth.current!,
      payload: slimPayload,
    );
    expect(await bob.messages.byEvent(event.id), isEmpty,
        reason: 'slim payload does not carry the activities');
    expect((await bob.members.byGroup(created.id)).length, 1,
        reason: 'only the joiner before the state sync');

    // --- State sync over the network.
    await bob.sync.requestGroupState(joined.id, code);
    await settle();

    // Members materialized (bob + alice + carol), users known.
    final bobMembers = await bob.members.byGroup(created.id);
    expect(bobMembers.map((m) => m.userId), containsAll(['alice', 'carol']));
    final carol = await bob.users.getById('carol');
    expect(carol?.displayName, 'Каролина');

    // Activities materialized with their original ids.
    final bobEvent = await bob.events.getById(event.id);
    expect(bobEvent, isNotNull);
    expect(bobEvent!.title, 'Вечерний выезд');

    // The organizer became an accepted participant.
    final organizerP =
        await bob.participants.byEventAndUser(event.id, 'alice');
    expect(organizerP, isNotNull);
  });

  test('a wrong invite code is not answered (authorization)', () async {
    final group = GroupCollection()..name = 'Closed club';
    group.ownerId = 'alice';
    group.inviteCode = code;
    final created = await alice.groups.create(group);
    await alice.members.addMember(
      groupId: created.id,
      userId: 'bob',
      role: GroupRole.member.name,
      canInvite: false,
      addedBy: 'alice',
    );

    // Bob KNOWS the group id but presents a wrong code.
    await bob.sync.requestGroupState(created.id, 'FFFFFFFF');
    await settle();

    // No batch came back: alice sent no groupStateBatch at all.
    expect(
        alice.hub.sent
            .where((e) => e.type == RealtimeType.groupStateBatch),
        isEmpty);
    expect(await alice.events.byGroup(created.id), isEmpty);
  });

  test('state batch ingest never overwrites existing local events',
      () async {
    final group = GroupCollection()..name = 'Merge test';
    group.ownerId = 'alice';
    group.inviteCode = code;
    final created = await alice.groups.create(group);
    final event = EventCollection()
      ..title = 'Локальная версия'
      ..startAt = 1725600000000
      ..groupId = created.id
      ..organizerId = 'alice';
    await alice.events.create(event);

    // Bob joins and ALREADY has a local event with the same id but
    // different content (local-first: local wins).
    final joined = await bob.groupService.acceptInvitation(
      user: bob.auth.current!,
      payload: alice.groupService.invitationPayload(created),
    );
    final localTwin = EventCollection()
      ..id = event.id
      ..title = 'СВОЯ локальная версия'
      ..startAt = 1725600000000
      ..groupId = joined.id
      ..organizerId = 'alice';
    await bob.events.upsertFromInvitation(localTwin);

    await bob.sync.requestGroupState(joined.id, code);
    await settle();

    final after = await bob.events.getById(event.id);
    expect(after!.title, 'СВОЯ локальная версия',
        reason: 'ingest is insert-only — local state wins');
  });

  test('V3.0.5 hotfix: history request must not throttle the state request',
      () async {
    // Owner side: group + owner membership + one activity.
    final group = GroupCollection()..name = 'Кулдауны';
    group.ownerId = 'alice';
    group.inviteCode = code;
    final created = await alice.groups.create(group);
    await alice.members.addMember(
      groupId: created.id,
      userId: 'alice',
      role: GroupRole.owner.name,
      addedBy: 'alice',
    );
    final event = EventCollection()
      ..title = 'Проверка кулдаунов'
      ..startAt = 1725600000000
      ..groupId = created.id
      ..organizerId = 'alice';
    await alice.events.create(event);

    // Bob joins via the slim payload.
    final joined = await bob.groupService.acceptInvitation(
      user: bob.auth.current!,
      payload: alice.groupService.invitationPayload(created),
    );

    // EXACT dispatcher sequence (deep_link_dispatcher.dart): the history
    // request is fired first, the state request immediately after. Before
    // the hotfix both shared one cooldown map keyed by groupId, so the
    // state request was silently dropped and the group page stayed empty.
    await bob.sync.requestHistory(joined.id);
    await bob.sync.requestGroupState(joined.id, code);
    await settle();

    // The state request really left the device…
    expect(
        bob.hub.sent.where((e) => e.type == RealtimeType.groupStateRequest),
        isNotEmpty);
    // …and alice answered it (the batch is sent by the OWNER device).
    final batches = alice.hub.sent
        .where((e) => e.type == RealtimeType.groupStateBatch)
        .toList();
    expect(batches, isNotEmpty,
        reason: 'state request must NOT be suppressed by the history cooldown');

    // The group page data is now on bob's device.
    expect((await bob.members.byGroup(joined.id)).map((m) => m.userId),
        contains('alice'));
    expect(await bob.events.getById(event.id), isNotNull);
  });

  test('V3.0.5 hotfix: UI change streams fire when the state batch lands',
      () async {
    // Owner side: group + owner membership + one activity.
    final group = GroupCollection()..name = 'Сигналы';
    group.ownerId = 'alice';
    group.inviteCode = code;
    final created = await alice.groups.create(group);
    await alice.members.addMember(
      groupId: created.id,
      userId: 'alice',
      role: GroupRole.owner.name,
      addedBy: 'alice',
    );
    final event = EventCollection()
      ..title = 'Сигнальная активность'
      ..startAt = 1725600000000
      ..groupId = created.id
      ..organizerId = 'alice';
    await alice.events.create(event);

    // Bob joins via the slim payload — his local state is minimal.
    final joined = await bob.groupService.acceptInvitation(
      user: bob.auth.current!,
      payload: alice.groupService.invitationPayload(created),
    );

    // Bob's open group page subscribes exactly like the tabs do.
    final memberSignals = <String>[];
    final eventSignals = <String>[];
    final sub1 = bob.members.groupChanges.listen(memberSignals.add);
    final sub2 = bob.events.groupChanges.listen(eventSignals.add);

    await bob.sync.requestGroupState(joined.id, code);
    await settle();
    await sub1.cancel();
    await sub2.cancel();

    // The page got reload signals for THIS group — that is what makes the
    // Members / Activities tabs fill in without leaving the page.
    expect(memberSignals, contains(joined.id),
        reason: 'roster ingest must notify the Members tab');
    expect(eventSignals, contains(joined.id),
        reason: 'activity ingest must notify the Activities tab');
  });

  test('V3.0.5 hotfix: state batch is split into small frames', () async {
    // Owner side: group + 20 activities → 20 / 8 = at least 3 frames.
    final group = GroupCollection()..name = 'Фреймы';
    group.ownerId = 'alice';
    group.inviteCode = code;
    final created = await alice.groups.create(group);
    await alice.members.addMember(
      groupId: created.id,
      userId: 'alice',
      role: GroupRole.owner.name,
      addedBy: 'alice',
    );
    for (var i = 0; i < 20; i++) {
      await alice.events.create(EventCollection()
        ..title = 'Активность $i'
        ..startAt = 1725600000000 + i * 60000
        ..groupId = created.id
        ..organizerId = 'alice');
    }

    // Bob joins via the slim payload.
    final joined = await bob.groupService.acceptInvitation(
      user: bob.auth.current!,
      payload: alice.groupService.invitationPayload(created),
    );
    await bob.sync.requestGroupState(joined.id, code);
    await settle();

    final batches = alice.hub.sent
        .where((e) => e.type == RealtimeType.groupStateBatch)
        .toList();
    expect(batches.length, greaterThanOrEqualTo(3),
        reason: '20 activities at 8 per frame must be split');

    // Every frame is small — no oversized datagrams, no reliance on
    // Wi-Fi IP fragmentation of broadcast packets.
    for (final b in batches) {
      final events = b.payload['events'] as List;
      expect(events.length, lessThanOrEqualTo(kGroupStateEventsPerFrame));
    }

    // Group doc + roster ride on the FIRST frame only.
    expect(batches.first.payload['group'], isNotNull);
    expect(batches.first.payload['members'], isNotNull);
    for (final b in batches.skip(1)) {
      expect(b.payload.containsKey('group'), isFalse);
      expect(b.payload.containsKey('members'), isFalse);
    }

    // The joiner materialized the whole state anyway — ingest is
    // idempotent and frame-order tolerant.
    expect((await bob.events.byGroup(joined.id)).length, 20);
    expect((await bob.members.byGroup(joined.id)).map((m) => m.userId),
        contains('alice'));
  });
}
