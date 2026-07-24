/// Local profile repository (Authentication is local — ADR-001 / Rule 6).
import 'package:sembast/sembast.dart';

import 'package:pokatuha/core/errors/app_error.dart';
import 'package:pokatuha/core/utils/timestamps.dart';
import 'package:pokatuha/core/utils/uuid.dart';
import 'package:pokatuha/database/collections/user_collection.dart';
import 'package:pokatuha/database/database.dart';

class UserRepository {
  UserRepository(this._db);
  final DatabaseService _db;

  TypedStore<UserCollection> get _store => _db.usersStore;

  /// The single local profile (local-first: there is one user on this device).
  Future<UserCollection?> getCurrent() async {
    final list = await _store.find(
      filter: Filter.equals('isDeleted', false),
      limit: 1,
    );
    return list.isEmpty ? null : list.first;
  }

  Future<UserCollection> requireCurrent() async {
    final user = await getCurrent();
    if (user == null) {
      throw const NotFoundError('No local profile found');
    }
    return user;
  }

  Future<UserCollection> createProfile({
    required String displayName,
    String? username,
    String? bio,
  }) async {
    final existing = await getCurrent();
    if (existing != null) {
      throw const BusinessRuleError('A local profile already exists');
    }
    final now = Timestamps.nowUtc();
    final user = UserCollection()
      ..id = UuidGenerator.generate()
      ..createdAt = now
      ..updatedAt = now
      ..version = 1
      ..isDeleted = false
      ..displayName = displayName.trim()
      ..username = (username ?? displayName.trim()).trim()
      ..bio = bio?.trim()
      ..profileVisible = true;
    return _store.put(user);
  }

  Future<UserCollection> updateProfile(UserCollection user) async {
    user.touch(Timestamps.nowUtc());
    return _store.put(user);
  }
}
