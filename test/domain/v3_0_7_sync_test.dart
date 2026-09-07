// V3.0.7 — unit tests for the live group sync (bug 1 & bug 2) and the
// author-name enrichment (bug 5). These tests exercise the new envelope
// types and the permission check without touching the network — the
// transport is a fake that captures every broadcast so we can assert on
// the outgoing payload.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:pokatuha/core/errors/app_error.dart';
import 'package:pokatuha/database/collections/event_collection.dart';
import 'package:pokatuha/database/collections/group_collection.dart';
import 'package:pokatuha/database/collections/group_member_collection.dart';
import 'package:pokatuha/database/collections/participant_collection.dart';
import 'package:pokatuha/database/collections/user_collection.dart';
import 'package:pokatuha/domain/enums/enums.dart';
import 'package:pokatuha/domain/repositories/archive_repository.dart';
import 'package:pokatuha/domain/repositories/event_repository.dart';
import 'package:pokatuha/domain/repositories/group_member_repository.dart';
import 'package:pokatuha/domain/repositories/group_repository.dart';
import 'package:pokatuha/domain/repositories/participant_repository.dart';
import 'package:pokatuha/domain/repositories/user_repository.dart';
import 'package:pokatuha/domain/services/communication_service.dart';
import 'package:pokatuha/domain/services/event_service.dart';
import 'package:pokatuha/domain/services/group_service.dart';

// ---------------------------------------------------------------------------
// Fakes & mocks
// ---------------------------------------------------------------------------

class _FakeTransport implements CommunicationService {
  final List<RealtimeEnvelope> broadcasts = <RealtimeEnvelope>[];
  final StreamController<RealtimeEnvelope> _incoming =
      StreamController<RealtimeEnvelope>.broadcast();

  @override
  CommunicationMode get mode => CommunicationMode.live;

  @override
  Stream<CommunicationMode> get modeStream => const Stream.empty();

  @override
  Stream<RealtimeEnvelope> get incoming => _incoming.stream;

  @override
  Future<void> connect({required String sessionId, required String peerToken}) async {}

  @override
  Future<void> broadcast(RealtimeEnvelope envelope) async {
    broadcasts.add(envelope);
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> onFcmWakeUp({required String sessionId}) async {}

  @override
  void enqueue(PendingChange change) {}

  @override
  List<PendingChange> get pendingQueue => const <PendingChange>[];

  @override
  Future<void> syncPending() async {}

  void emit(RealtimeEnvelope envelope) => _incoming.add(envelope);
}

class _MockEventRepository extends Mock implements EventRepository {}

class _MockParticipantRepository extends Mock implements ParticipantRepository {}

class _MockArchiveRepository extends Mock implements ArchiveRepository {}

class _MockGroupRepository extends Mock implements GroupRepository {}

class _MockGroupMemberRepository extends Mock implements GroupMemberRepository {}

class _MockUserRepository extends Mock implements UserRepository {}

EventCollection _event({
  required String id,
  required String groupId,
  required String organizerId,
  String title = 'Test Activity',
  int version = 1,
}) {
  return EventCollection()
    ..id = id
    ..groupId = groupId
    ..title = title
    ..description = ''
    ..startAt = 1700000000000
    ..activityTypeId = 'MTB'
    ..organizerId = organizerId
    ..visibility = EventVisibility.private.name
    ..accentColor = 0xFF6750A4
    ..arrivalThresholdNear = 500
    ..arrivalThresholdClose = 200
    ..arrivalThresholdArrived = 50
    ..createdBy = organizerId
    ..version = version;
}

UserCollection _user({
  required String id,
  String displayName = 'Test User',
  String username = 'testuser',
}) {
  return UserCollection()
    ..id = id
    ..displayName = displayName
    ..username = username;
}

GroupCollection _group({
  required String id,
  required String ownerId,
  String? inviteCode,
}) {
  return GroupCollection()
    ..id = id
    ..name = 'Test Group'
    ..type = GroupType.public.name
    ..ownerId = ownerId
    ..inviteCode = inviteCode ?? 'ABC123';
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue('');
    registerFallbackValue(0);
    registerFallbackValue(true);
    registerFallbackValue(EventCollection());
    registerFallbackValue(GroupCollection());
    registerFallbackValue(GroupMemberCollection());
    registerFallbackValue(ParticipantCollection());
    registerFallbackValue(UserCollection());
    registerFallbackValue(ParticipantStatus.accepted);
  });

  group('EventService — V3.0.7 bug 2 (broadcast + permission)', () {
    late _FakeTransport transport;
    late _MockEventRepository events;
    late _MockParticipantRepository participants;
    late _MockArchiveRepository archive;
    late _MockGroupMemberRepository members;
    late EventService service;

    setUp(() {
      transport = _FakeTransport();
      events = _MockEventRepository();
      participants = _MockParticipantRepository();
      archive = _MockArchiveRepository();
      members = _MockGroupMemberRepository();
      service = EventService(
        events,
        participants,
        archive,
        transport: transport,
        memberRepository: members,
      );
    });

    test('createActivity broadcasts an activityUpsert envelope', () async {
      final organizer = _user(id: 'u1');
      final created = _event(
        id: 'e1',
        groupId: 'g1',
        organizerId: organizer.id,
        title: 'Group Ride',
      );
      when(() => events.create(any())).thenAnswer((_) async => created);
      final organizerP = ParticipantCollection()..userId = organizer.id;
      when(() => participants.invite(
            eventId: any(named: 'eventId'),
            userId: any(named: 'userId'),
            role: any(named: 'role'),
            byUserId: any(named: 'byUserId'),
          )).thenAnswer((_) async => organizerP);
      when(() => participants.byEventAndUser('e1', organizer.id))
          .thenAnswer((_) async => organizerP);
      when(() => participants.setStatus(any(), any()))
          .thenAnswer((_) async => organizerP);

      final result = await service.createActivity(
        organizer: organizer,
        groupId: 'g1',
        title: 'Group Ride',
        description: '',
        startAt: 1700000000000,
        activityTypeId: 'MTB',
      );

      expect(result.title, 'Group Ride');
      // The broadcast must have fired exactly once with op=create.
      final upserts = transport.broadcasts
          .where((e) => e.type == RealtimeType.activityUpsert)
          .toList();
      expect(upserts.length, 1);
      expect(upserts.first.payload['op'], 'create');
      expect(upserts.first.payload['groupId'], 'g1');
      expect(upserts.first.payload['event']['id'], 'e1');
    });

    test(
        'editActivity throws BusinessRuleError when a regular member edits '
        'someone else\'s activity (option C — organizer + admin only)', () async {
      final event = _event(
        id: 'e1',
        groupId: 'g1',
        organizerId: 'organizer',
      );
      // The current user is a regular member of the group.
      when(() => members.byGroupAndUser('g1', 'member1')).thenAnswer(
        (_) async => GroupMemberCollection()
          ..userId = 'member1'
          ..role = GroupRole.member.name,
      );

      await expectLater(
        service.editActivity(
          event: event,
          title: 'Changed',
          description: '',
          startAt: 1700000000000,
          activityTypeId: 'MTB',
          byUserId: 'member1',
        ),
        throwsA(isA<BusinessRuleError>()),
      );
    });

    test('editActivity allows the organizer of the activity', () async {
      final event = _event(
        id: 'e1',
        groupId: 'g1',
        organizerId: 'organizer',
      );
      when(() => events.update(any())).thenAnswer((_) async => event);

      final result = await service.editActivity(
        event: event,
        title: 'Changed',
        description: '',
        startAt: 1700000000000,
        activityTypeId: 'MTB',
        byUserId: 'organizer',
      );

      expect(result.title, 'Changed');
      // The edit must also broadcast an activityUpsert with op=update.
      final upserts = transport.broadcasts
          .where((e) => e.type == RealtimeType.activityUpsert)
          .toList();
      expect(upserts.length, 1);
      expect(upserts.first.payload['op'], 'update');
    });

    test('editActivity allows a group admin', () async {
      final event = _event(
        id: 'e1',
        groupId: 'g1',
        organizerId: 'organizer',
      );
      when(() => members.byGroupAndUser('g1', 'admin1')).thenAnswer(
        (_) async => GroupMemberCollection()
          ..userId = 'admin1'
          ..role = GroupRole.admin.name,
      );
      when(() => events.update(any())).thenAnswer((_) async => event);

      final result = await service.editActivity(
        event: event,
        title: 'Admin Edit',
        description: '',
        startAt: 1700000000000,
        activityTypeId: 'MTB',
        byUserId: 'admin1',
      );

      expect(result.title, 'Admin Edit');
    });
  });

  group('GroupService — V3.0.7 bug 1 (memberAdded broadcast)', () {
    late _FakeTransport transport;
    late _MockGroupRepository groups;
    late _MockGroupMemberRepository members;
    late _MockEventRepository events;
    late _MockUserRepository users;
    late _MockParticipantRepository participants;
    late GroupService service;

    setUp(() {
      transport = _FakeTransport();
      groups = _MockGroupRepository();
      members = _MockGroupMemberRepository();
      events = _MockEventRepository();
      users = _MockUserRepository();
      participants = _MockParticipantRepository();
      service = GroupService(
        groups,
        members,
        events,
        users,
        participants,
        transport: transport,
      );
    });

    test('inviteMember broadcasts a memberAdded envelope with the user info',
        () async {
      final group = _group(id: 'g1', ownerId: 'owner');
      final invitee = _user(
        id: 'u2',
        displayName: 'Alice',
        username: 'alice',
      );
      when(() => members.byGroupAndUser('g1', 'u2'))
          .thenAnswer((_) async => null);
      when(() => members.countByGroup('g1')).thenAnswer((_) async => 1);
      when(() => members.addMember(
            groupId: any(named: 'groupId'),
            userId: any(named: 'userId'),
            role: any(named: 'role'),
            addedBy: any(named: 'addedBy'),
            canInvite: any(named: 'canInvite'),
            joinedAt: any(named: 'joinedAt'),
          )).thenAnswer((_) async => GroupMemberCollection());

      await service.inviteMember(
        group: group,
        user: invitee,
        addedBy: 'owner',
      );

      final memberAdded = transport.broadcasts
          .where((e) => e.type == RealtimeType.memberAdded)
          .toList();
      expect(memberAdded.length, 1);
      expect(memberAdded.first.payload['groupId'], 'g1');
      expect(memberAdded.first.payload['member']['userId'], 'u2');
      expect(memberAdded.first.payload['member']['displayName'], 'Alice');
      expect(memberAdded.first.payload['member']['username'], 'alice');
      expect(memberAdded.first.payload['user']['displayName'], 'Alice');
    });

    test('inviteMember still throws when the user is already a member',
        () async {
      final group = _group(id: 'g1', ownerId: 'owner');
      final invitee = _user(id: 'u2');
      when(() => members.byGroupAndUser('g1', 'u2')).thenAnswer(
        (_) async => GroupMemberCollection()..userId = 'u2',
      );

      await expectLater(
        service.inviteMember(
          group: group,
          user: invitee,
          addedBy: 'owner',
        ),
        throwsA(isA<BusinessRuleError>()),
      );
      // No broadcast should have fired.
      expect(
        transport.broadcasts
            .where((e) => e.type == RealtimeType.memberAdded)
            .length,
        0,
      );
    });
  });
}
