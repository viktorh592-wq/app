import 'package:flutter_test/flutter_test.dart';
import 'package:pokatuha/database/collections/group_collection.dart';
import 'package:pokatuha/database/database.dart';
import 'package:pokatuha/domain/enums/enums.dart';
import 'package:pokatuha/domain/repositories/group_repository.dart';

void main() {
  late DatabaseService db;
  late GroupRepository repo;

  setUp(() async {
    db = await DatabaseService.memory();
    repo = GroupRepository(db);
  });

  tearDown(() => db.close());

  GroupCollection makeGroup({
    String name = 'Weekend Riders',
    String type = 'public',
    bool discoverable = true,
  }) =>
      GroupCollection()
        ..name = name
        ..type = type
        ..ownerId = 'user-1'
        ..discoverable = discoverable;

  test('create persists with UUID, invite code and timestamps', () async {
    final g = await repo.create(makeGroup());
    expect(g.id, isNotEmpty);
    expect(g.createdAt, greaterThan(0));
    expect(g.version, 1);
    expect(g.inviteCode, isNotNull);
    expect(g.inviteCode!.length, 8);
    expect(g.type, GroupType.public.name);
  });

  test('create generates a deterministic invite code from the id', () async {
    final g = await repo.create(makeGroup());
    final expected = g.id.replaceAll('-', '').substring(0, 8).toUpperCase();
    expect(g.inviteCode, expected);
  });

  test('create rejects nothing — name validated on service level', () async {
    // Repository accepts the entity as-is; business rules live in
    // GroupService (architecture layering).
    final g = await repo.create(makeGroup(name: '  '));
    expect(g.name, '  ');
  });

  test('getById returns only non-deleted', () async {
    final g = await repo.create(makeGroup());
    expect((await repo.getById(g.id))?.id, g.id);
    await repo.softDelete(g);
    expect(await repo.getById(g.id), isNull);
  });

  test('getByInviteCode finds the group case-insensitively', () async {
    final g = await repo.create(makeGroup());
    final found = await repo.getByInviteCode(g.inviteCode!.toLowerCase());
    expect(found?.id, g.id);
    expect(await repo.getByInviteCode('DEADBEEF'), isNull);
  });

  test('searchByName returns only discoverable groups', () async {
    await repo.create(makeGroup(name: 'MTB Crew'));
    await repo.create(makeGroup(
      name: 'Secret MTB Club',
      type: 'private',
      discoverable: false,
    ));
    final results = await repo.searchByName('mtb');
    expect(results.length, 1);
    expect(results.first.name, 'MTB Crew');
    expect(await repo.searchByName('   '), isEmpty);
  });

  test('update bumps version and touches updatedAt', () async {
    final g = await repo.create(makeGroup());
    final before = g.updatedAt;
    g.name = 'Renamed';
    final updated = await repo.update(g);
    expect(updated.name, 'Renamed');
    expect(updated.version, 2);
    expect(updated.updatedAt, greaterThanOrEqualTo(before));
  });
}
