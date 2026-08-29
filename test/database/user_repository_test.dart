/// Tests for local user discovery (V2 USER_DISCOVERY.md §1–§2):
/// nickname search and lookup by short public id.
import 'package:flutter_test/flutter_test.dart';
import 'package:pokatuha/core/utils/timestamps.dart';
import 'package:pokatuha/core/utils/uuid.dart';
import 'package:pokatuha/database/collections/user_collection.dart';
import 'package:pokatuha/database/database.dart';
import 'package:pokatuha/domain/repositories/user_repository.dart';
import 'package:pokatuha/domain/services/identity_service.dart';

void main() {
  late DatabaseService db;
  late UserRepository repo;

  setUp(() async {
    db = await DatabaseService.memory();
    repo = UserRepository(db);
  });

  tearDown(() => db.close());

  /// Inserts a locally-known peer (discovered via QR / contact exchange)
  /// directly into the store — createProfile guards a single local profile.
  Future<UserCollection> insertPeer(
    String name,
    String username, {
    bool visible = true,
  }) async {
    final now = Timestamps.nowUtc();
    final user = UserCollection()
      ..id = UuidGenerator.generate()
      ..createdAt = now
      ..updatedAt = now
      ..version = 1
      ..isDeleted = false
      ..displayName = name
      ..username = username
      ..profileVisible = visible;
    return db.usersStore.put(user);
  }

  test('searchByNickname finds users by partial nickname', () async {
    await repo.createProfile(displayName: 'Me', username: 'me');
    await insertPeer('Alex', 'alex_ride');
    await insertPeer('Bro', 'mtb_bro');
    final results = await repo.searchByNickname('alex');
    expect(results.length, 1);
    expect(results.first.username, 'alex_ride');
  });

  test('searchByNickname is case-insensitive and matches display names',
      () async {
    await insertPeer('Viktor', 'vik');
    final byNickname = await repo.searchByNickname('VIK');
    final byDisplay = await repo.searchByNickname('vikt');
    expect(byNickname.length, 1);
    expect(byDisplay.length, 1);
  });

  test('searchByNickname skips hidden profiles (Privacy — §3)', () async {
    await insertPeer('Hidden', 'ghost', visible: false);
    expect(await repo.searchByNickname('ghost'), isEmpty);
  });

  test('searchByNickname returns empty for an empty query', () async {
    await insertPeer('Alex', 'alex');
    expect(await repo.searchByNickname('   '), isEmpty);
    expect(await repo.searchByNickname(''), isEmpty);
  });

  test('findByPublicId resolves the short id from pokatuha://u/<ID>', () async {
    final user = await insertPeer('Alex', 'alex');
    final shortId = IdentityService().publicId(user.id);
    final found = await repo.findByPublicId(shortId.toLowerCase());
    expect(found?.id, user.id);
    expect(await repo.findByPublicId('FFFFFFFFFF00'), isNull);
    expect(await repo.findByPublicId(''), isNull);
  });
}
