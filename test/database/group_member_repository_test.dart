import 'package:flutter_test/flutter_test.dart';
import 'package:pokatuha/database/database.dart';
import 'package:pokatuha/domain/enums/enums.dart';
import 'package:pokatuha/domain/repositories/group_member_repository.dart';

void main() {
  late DatabaseService db;
  late GroupMemberRepository repo;

  setUp(() async {
    db = await DatabaseService.memory();
    repo = GroupMemberRepository(db);
  });

  tearDown(() => db.close());

  test('addMember persists with role and joinedAt', () async {
    final m = await repo.addMember(
      groupId: 'group-1',
      userId: 'user-1',
      role: GroupRole.owner.name,
      addedBy: 'user-1',
    );
    expect(m.id, isNotEmpty);
    expect(m.groupId, 'group-1');
    expect(m.userId, 'user-1');
    expect(m.role, GroupRole.owner.name);
    expect(m.joinedAt, greaterThan(0));
    expect(m.isDeleted, isFalse);
  });

  test('addMember is idempotent for the same user and group', () async {
    final first = await repo.addMember(
      groupId: 'group-1',
      userId: 'user-1',
    );
    final second = await repo.addMember(
      groupId: 'group-1',
      userId: 'user-1',
    );
    expect(second.id, first.id);
    expect(await repo.countByGroup('group-1'), 1);
  });

  test('byGroupAndUser finds the membership', () async {
    await repo.addMember(groupId: 'group-1', userId: 'user-1');
    expect(
        (await repo.byGroupAndUser('group-1', 'user-1'))?.groupId, 'group-1');
    expect(await repo.byGroupAndUser('group-1', 'user-2'), isNull);
    expect(await repo.byGroupAndUser('group-2', 'user-1'), isNull);
  });

  test('byUser lists memberships across groups', () async {
    await repo.addMember(groupId: 'group-1', userId: 'user-1');
    await repo.addMember(groupId: 'group-2', userId: 'user-1');
    await repo.addMember(groupId: 'group-1', userId: 'user-2');
    final mine = await repo.byUser('user-1');
    expect(mine.length, 2);
    expect(mine.map((m) => m.groupId).toSet(), {'group-1', 'group-2'});
  });

  test('removeMember soft-deletes the membership', () async {
    final m = await repo.addMember(
      groupId: 'group-1',
      userId: 'user-1',
    );
    await repo.removeMember(m);
    expect(await repo.byGroupAndUser('group-1', 'user-1'), isNull);
    expect(await repo.countByGroup('group-1'), 0);
    // The record itself remains (soft delete — Soft_Delete.md).
    final raw = await db.groupMembersStore.getById(m.id);
    expect(raw, isNotNull);
    expect(raw!.isDeleted, isTrue);
  });
}
