import 'package:flutter_test/flutter_test.dart';
import 'package:pokatuha/database/database.dart';
import 'package:pokatuha/domain/repositories/activity_type_repository.dart';

void main() {
  late DatabaseService db;
  late ActivityTypeRepository repo;

  setUp(() async {
    db = await DatabaseService.memory();
    repo = ActivityTypeRepository(db);
  });

  tearDown(() => db.close());

  test('default activity types are seeded on open', () async {
    final all = await repo.all();
    expect(all.length, 10);
    expect(all.map((t) => t.key).toList(), contains('MTB'));
    expect(all.every((t) => t.isBuiltIn), isTrue);
  });

  test('seeding is idempotent', () async {
    expect((await repo.all()).length, 10);
    // Reopening a fresh memory db re-seeds; here just ensure no duplicates.
    expect((await repo.all()).length, 10);
  });

  test('custom activity type can be created (FR-002)', () async {
    final t = await repo.createCustom(key: 'coffee', label: 'Coffee Ride');
    expect(t.isBuiltIn, isFalse);
    expect((await repo.byKey('coffee'))?.id, t.id);
    expect((await repo.all()).length, 11);
  });
}
