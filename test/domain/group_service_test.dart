import 'package:flutter_test/flutter_test.dart';
import 'package:pokatuha/core/errors/app_error.dart';
import 'package:pokatuha/core/utils/timestamps.dart';
import 'package:pokatuha/core/utils/uuid.dart';
import 'package:pokatuha/database/collections/user_collection.dart';
import 'package:pokatuha/database/database.dart';
import 'package:pokatuha/domain/enums/enums.dart';
import 'package:pokatuha/domain/repositories/event_repository.dart';
import 'package:pokatuha/domain/repositories/group_member_repository.dart';
import 'package:pokatuha/domain/repositories/group_repository.dart';
import 'package:pokatuha/domain/repositories/participant_repository.dart';
import 'package:pokatuha/domain/repositories/user_repository.dart';
import 'package:pokatuha/domain/services/group_service.dart';

/// Inserts a locally-known user directly into the store (peers discovered
/// via QR / contact exchange are not created through createProfile —
/// that guard allows only one local profile per device).
Future<UserCollection> insertKnownUser(
  DatabaseService db,
  String name,
  String username,
) async {
  final now = Timestamps.nowUtc();
  final user = UserCollection()
    ..id = UuidGenerator.generate()
    ..createdAt = now
    ..updatedAt = now
    ..version = 1
    ..isDeleted = false
    ..displayName = name
    ..username = username
    ..profileVisible = true;
  return db.usersStore.put(user);
}

void main() {
  late DatabaseService db;
  late GroupService service;
  late GroupMemberRepository members;

  setUp(() async {
    db = await DatabaseService.memory();
    members = GroupMemberRepository(db);
    service = GroupService(
      GroupRepository(db),
      members,
      EventRepository(db),
      UserRepository(db),
      ParticipantRepository(db),
    );
  });

  tearDown(() => db.close());

  Future<UserCollection> makeUser(String name) =>
      insertKnownUser(db, name, name.toLowerCase());

  test('createGroup rejects an empty name', () async {
    final owner = await makeUser('Alex');
    expect(
      () => service.createGroup(owner: owner, name: '   '),
      throwsA(isA<BusinessRuleError>()),
    );
  });

  test('createGroup adds the owner as a member with owner role (§4)', () async {
    final owner = await makeUser('Alex');
    final group = await service.createGroup(
      owner: owner,
      name: 'Weekend Riders',
      type: GroupType.public,
    );
    expect(group.name, 'Weekend Riders');
    expect(group.type, GroupType.public.name);
    expect(group.ownerId, owner.id);
    expect(group.inviteCode, isNotNull);

    final membership = await members.byGroupAndUser(group.id, owner.id);
    expect(membership, isNotNull);
    expect(membership!.role, GroupRole.owner.name);
  });

  test('public group is discoverable, private is not', () async {
    final owner = await makeUser('Alex');
    final public = await service.createGroup(
        owner: owner, name: 'P', type: GroupType.public);
    final private = await service.createGroup(
        owner: owner, name: 'R', type: GroupType.private);
    expect(public.discoverable, isTrue);
    expect(private.discoverable, isFalse);
  });

  test('joinByInviteCode joins a public group', () async {
    final owner = await makeUser('Alex');
    final guest = await makeUser('Bro');
    final group = await service.createGroup(
        owner: owner, name: 'Crew', type: GroupType.public);
    final joined = await service.joinByInviteCode(
      user: guest,
      code: group.inviteCode!.toLowerCase(),
    );
    expect(joined.id, group.id);
    final membership = await members.byGroupAndUser(group.id, guest.id);
    expect(membership?.role, GroupRole.member.name);
  });

  test('joinByInviteCode rejects a private group', () async {
    final owner = await makeUser('Alex');
    final guest = await makeUser('Bro');
    final group = await service.createGroup(
        owner: owner, name: 'Secret', type: GroupType.private);
    expect(
      () => service.joinByInviteCode(user: guest, code: group.inviteCode!),
      throwsA(isA<BusinessRuleError>()),
    );
  });

  test('joinByInviteCode throws NotFound for an unknown code', () async {
    final guest = await makeUser('Bro');
    expect(
      () => service.joinByInviteCode(user: guest, code: 'DEADBEEF'),
      throwsA(isA<NotFoundError>()),
    );
  });

  test('joinByInviteCode is idempotent for an existing member', () async {
    final owner = await makeUser('Alex');
    final group = await service.createGroup(
        owner: owner, name: 'Crew', type: GroupType.public);
    await service.joinByInviteCode(user: owner, code: group.inviteCode!);
    expect(await members.countByGroup(group.id), 1);
  });

  test('inviteMember adds a member and rejects duplicates', () async {
    final owner = await makeUser('Alex');
    final friend = await makeUser('Bro');
    final group = await service.createGroup(owner: owner, name: 'Crew');
    await service.inviteMember(group: group, user: friend, addedBy: owner.id);
    expect(await members.countByGroup(group.id), 2);
    expect(
      () => service.inviteMember(group: group, user: friend, addedBy: owner.id),
      throwsA(isA<BusinessRuleError>()),
    );
  });

  test('owner cannot leave — transfer ownership first (§4)', () async {
    final owner = await makeUser('Alex');
    final group = await service.createGroup(owner: owner, name: 'Crew');
    expect(
      () => service.leaveGroup(group: group, user: owner),
      throwsA(isA<BusinessRuleError>()),
    );
  });

  test('member can leave the group', () async {
    final owner = await makeUser('Alex');
    final member = await makeUser('Bro');
    final group = await service.createGroup(
        owner: owner, name: 'Crew', type: GroupType.public);
    await service.joinByInviteCode(user: member, code: group.inviteCode!);
    await service.leaveGroup(group: group, user: member);
    expect(await members.byGroupAndUser(group.id, member.id), isNull);
  });

  test('leaveGroup throws NotFound for a stranger', () async {
    final owner = await makeUser('Alex');
    final stranger = await makeUser('Zed');
    final group = await service.createGroup(owner: owner, name: 'Crew');
    expect(
      () => service.leaveGroup(group: group, user: stranger),
      throwsA(isA<NotFoundError>()),
    );
  });

  test('deleteGroup is owner-only', () async {
    final owner = await makeUser('Alex');
    final other = await makeUser('Bro');
    final group = await service.createGroup(owner: owner, name: 'Crew');
    expect(
      () => service.deleteGroup(group: group, byUserId: other.id),
      throwsA(isA<BusinessRuleError>()),
    );
    await service.deleteGroup(group: group, byUserId: owner.id);
    expect(await db.groupsStore.getById(group.id), isNotNull);
    expect((await db.groupsStore.getById(group.id))!.isDeleted, isTrue);
  });

  test('canManage is true for owner and admin only', () async {
    final owner = await makeUser('Alex');
    final member = await makeUser('Bro');
    final group = await service.createGroup(
        owner: owner, name: 'Crew', type: GroupType.public);
    await service.joinByInviteCode(user: member, code: group.inviteCode!);
    expect(await service.canManage(group.id, owner.id), isTrue);
    expect(await service.canManage(group.id, member.id), isFalse);
    expect(await service.canManage(group.id, 'stranger'), isFalse);
  });

  // V3.0.3 fix (user feedback) — the invitation payload now carries the
  // full member roster + activities, and the receiver materializes them.
  // V3.0.5: the QR payload was slimmed down (bug 3) — members / activities
  // now arrive via the groupState sync; acceptInvitation keeps supporting
  // the legacy full payloads from older builds.
  group('V3.0.3/V3.0.5 — invitation payload + acceptInvitation', () {
    test('invitationPayload is slim — no members / activities (V3.0.5)',
        () async {
      final owner = await makeUser('Alex');
      final group = await service.createGroup(
        owner: owner,
        name: 'Crew',
        type: GroupType.public,
      );
      final payload = service.invitationPayload(group);
      expect(payload['id'], group.id);
      expect(payload['name'], 'Crew');
      expect(payload['inviteCode'], isNotNull);
      expect(payload.containsKey('members'), isFalse,
          reason: 'V3.0.5: members are no longer embedded in the QR');
      expect(payload.containsKey('activities'), isFalse,
          reason: 'V3.0.5: activities are no longer embedded in the QR');
    });

    test('acceptInvitation materializes members and activities from a '
        'LEGACY full payload on the receiver device', () async {
      // Sender side: owner creates a group, invites a friend, creates an
      // activity in the group.
      final owner = await makeUser('Alex');
      final friend = await makeUser('Bro');
      final group = await service.createGroup(
        owner: owner,
        name: 'Crew',
        type: GroupType.public,
      );
      await service.inviteMember(
        group: group,
        user: friend,
        addedBy: owner.id,
      );
      // Build a LEGACY full payload (what V3.0.3 QRs carried) to pin the
      // backwards-compatible materialization path.
      final payload = service.invitationPayload(group);
      payload['members'] = [
        {
          'userId': owner.id,
          'displayName': 'Alex',
          'username': 'alex',
          'role': GroupRole.owner.name,
          'canInvite': true,
          'joinedAt': null,
        },
        {
          'userId': friend.id,
          'displayName': 'Bro',
          'username': 'bro',
          'role': GroupRole.member.name,
          'canInvite': false,
          'joinedAt': null,
        },
      ];
      // Inject an activity into the payload (as the QR would carry it).
      final activityId = UuidGenerator.generate();
      payload['activities'] = [
        {
          'id': activityId,
          'title': 'Night Ride',
          'description': 'desc',
          'startAt': Timestamps.nowUtc() + 86400000,
          'activityTypeId': 'MTB',
          'visibility': EventVisibility.public.name,
          'organizerId': owner.id,
          'meetingPoint': {'lat': 50.45, 'lng': 30.52},
          'meetingPointLabel': 'Park',
          'maxParticipants': null,
          'accentColor': 0xFF9B8AFB,
          'pinnedInGroup': false,
          'status': EventStatus.preparation.name,
        }
      ];

      // Receiver side: simulate a fresh device by creating a new in-memory
      // DB and a guest user.
      final rxDb = await DatabaseService.memory();
      final rxService = GroupService(
        GroupRepository(rxDb),
        GroupMemberRepository(rxDb),
        EventRepository(rxDb),
        UserRepository(rxDb),
        ParticipantRepository(rxDb),
      );
      final guest = await rxDb.usersStore.put(UserCollection()
        ..id = UuidGenerator.generate()
        ..createdAt = Timestamps.nowUtc()
        ..updatedAt = Timestamps.nowUtc()
        ..version = 1
        ..isDeleted = false
        ..displayName = 'Guest'
        ..username = 'guest'
        ..profileVisible = true);
      final accepted = await rxService.acceptInvitation(
        user: guest,
        payload: payload,
      );
      expect(accepted.id, group.id);
      expect(accepted.name, 'Crew');

      // The receiver sees the owner and friend as members of the group
      // (in addition to themselves).
      final rxMembers = GroupMemberRepository(rxDb);
      final roster = await rxMembers.byGroup(group.id);
      expect(roster.length, 3); // owner, friend, guest
      final guestMember =
          roster.firstWhere((m) => m.userId == guest.id);
      expect(guestMember.role, GroupRole.member.name);

      // The receiver sees the activity in the group, with the original id
      // preserved.
      final rxEvents = EventRepository(rxDb);
      final list = await rxEvents.byGroup(group.id);
      expect(list.length, 1);
      expect(list.first.id, activityId);
      expect(list.first.title, 'Night Ride');
      expect(list.first.visibility, EventVisibility.public.name);
      expect(list.first.meetingPoint?.lat, closeTo(50.45, 0.0001));

      // The receiver also materialized the activity organizer as a
      // participant (with role = organizer, status = accepted).
      final rxParticipants = ParticipantRepository(rxDb);
      final organizerP =
          await rxParticipants.byEventAndUser(activityId, owner.id);
      expect(organizerP, isNotNull);
      expect(organizerP!.role, 'organizer');
      expect(organizerP.status, 'accepted');

      // And the owner's UserCollection was materialized so the receiver's
      // Members tab shows the proper displayName / username.
      final rxUsers = UserRepository(rxDb);
      final ownerUser = await rxUsers.getById(owner.id);
      expect(ownerUser, isNotNull);
      expect(ownerUser!.displayName, 'Alex');
      expect(ownerUser.username, 'alex');

      await rxDb.close();
    });

    test('acceptInvitation is idempotent — re-accepting does not duplicate '
        'members or activities', () async {
      final owner = await makeUser('Alex');
      final group = await service.createGroup(
        owner: owner,
        name: 'Crew',
        type: GroupType.public,
      );
      final payload = service.invitationPayload(group);
      payload['members'] = [
        {
          'userId': owner.id,
          'displayName': 'Alex',
          'username': 'alex',
          'role': GroupRole.owner.name,
          'canInvite': true,
          'joinedAt': null,
        },
      ];

      final rxDb = await DatabaseService.memory();
      final rxService = GroupService(
        GroupRepository(rxDb),
        GroupMemberRepository(rxDb),
        EventRepository(rxDb),
        UserRepository(rxDb),
        ParticipantRepository(rxDb),
      );
      final guest = await rxDb.usersStore.put(UserCollection()
        ..id = UuidGenerator.generate()
        ..createdAt = Timestamps.nowUtc()
        ..updatedAt = Timestamps.nowUtc()
        ..version = 1
        ..isDeleted = false
        ..displayName = 'Guest'
        ..username = 'guest'
        ..profileVisible = true);
      await rxService.acceptInvitation(user: guest, payload: payload);
      await rxService.acceptInvitation(user: guest, payload: payload);
      final rxMembers = GroupMemberRepository(rxDb);
      final roster = await rxMembers.byGroup(group.id);
      expect(roster.length, 2); // owner + guest, no duplicates
      await rxDb.close();
    });
  });

  group('V3.0.3 — canInvite permission', () {
    test('owner and admin implicitly canInviteToActivities', () async {
      final owner = await makeUser('Alex');
      final member = await makeUser('Bro');
      final group = await service.createGroup(
        owner: owner,
        name: 'Crew',
        type: GroupType.public,
      );
      await service.inviteMember(
        group: group,
        user: member,
        addedBy: owner.id,
      );
      expect(await service.canInviteToActivities(group.id, owner.id), isTrue);
      expect(
          await service.canInviteToActivities(group.id, member.id), isFalse);
    });

    test('setCanInvite grants and revokes the permission', () async {
      final owner = await makeUser('Alex');
      final member = await makeUser('Bro');
      final group = await service.createGroup(
        owner: owner,
        name: 'Crew',
        type: GroupType.public,
      );
      await service.inviteMember(
        group: group,
        user: member,
        addedBy: owner.id,
      );
      await service.setCanInvite(
        groupId: group.id,
        memberId: member.id,
        canInvite: true,
        byUserId: owner.id,
      );
      expect(
          await service.canInviteToActivities(group.id, member.id), isTrue);
      await service.setCanInvite(
        groupId: group.id,
        memberId: member.id,
        canInvite: false,
        byUserId: owner.id,
      );
      expect(
          await service.canInviteToActivities(group.id, member.id), isFalse);
    });

    test('setCanInvite rejects non-admin callers', () async {
      final owner = await makeUser('Alex');
      final member1 = await makeUser('Bro');
      final member2 = await makeUser('Zed');
      final group = await service.createGroup(
        owner: owner,
        name: 'Crew',
        type: GroupType.public,
      );
      await service.inviteMember(group: group, user: member1, addedBy: owner.id);
      await service.inviteMember(group: group, user: member2, addedBy: owner.id);
      expect(
        () => service.setCanInvite(
          groupId: group.id,
          memberId: member2.id,
          canInvite: true,
          byUserId: member1.id,
        ),
        throwsA(isA<BusinessRuleError>()),
      );
    });

    test('setRole promotes / demotes between admin and member', () async {
      final owner = await makeUser('Alex');
      final member = await makeUser('Bro');
      final group = await service.createGroup(
        owner: owner,
        name: 'Crew',
        type: GroupType.public,
      );
      await service.inviteMember(group: group, user: member, addedBy: owner.id);
      await service.setRole(
        groupId: group.id,
        memberId: member.id,
        role: GroupRole.admin,
        byUserId: owner.id,
      );
      expect(
        (await members.byGroupAndUser(group.id, member.id))?.role,
        GroupRole.admin.name,
      );
      // Admins implicitly canInvite.
      expect(
          await service.canInviteToActivities(group.id, member.id), isTrue);
      await service.setRole(
        groupId: group.id,
        memberId: member.id,
        role: GroupRole.member,
        byUserId: owner.id,
      );
      expect(
        (await members.byGroupAndUser(group.id, member.id))?.role,
        GroupRole.member.name,
      );
    });
  });
}
