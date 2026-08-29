import 'package:flutter_test/flutter_test.dart';
import 'package:pokatuha/core/errors/app_error.dart';
import 'package:pokatuha/core/utils/timestamps.dart';
import 'package:pokatuha/core/utils/uuid.dart';
import 'package:pokatuha/database/collections/user_collection.dart';
import 'package:pokatuha/database/database.dart';
import 'package:pokatuha/domain/enums/enums.dart';
import 'package:pokatuha/domain/repositories/group_member_repository.dart';
import 'package:pokatuha/domain/repositories/group_repository.dart';
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
}
