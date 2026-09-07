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

  /// A locally known user by id (null — unknown or deleted).
  Future<UserCollection?> getById(String id) async {
    final u = await _store.getById(id);
    return (u != null && !u.isDeleted) ? u : null;
  }

  /// All locally known non-deleted users, capped for snapshot use
  /// (V3.0.5 — the keep-alive task needs id → display name for
  /// notifications without touching the database).
  Future<List<UserCollection>> knownUsers({int limit = 300}) async =>
      _store.find(
        filter: Filter.equals('isDeleted', false),
        limit: limit,
      );

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

  /// V3.0.3 fix (user feedback): upsert a locally-known peer user (NOT
  /// the local profile — use [createProfile] for that). Used when
  /// materializing group members from a deep-link payload: if the user
  /// already exists locally, do nothing (we don't overwrite displayName /
  /// username with stale data from the inviter's device — local wins).
  /// Otherwise insert the record as-is.
  Future<UserCollection> upsertKnown(UserCollection user) async {
    final existing = await _store.getById(user.id);
    if (existing != null && !existing.isDeleted) return existing;
    final now = Timestamps.nowUtc();
    if (user.createdAt == 0) user.createdAt = now;
    if (user.updatedAt == 0) user.updatedAt = now;
    if (user.version < 1) user.version = 1;
    return _store.put(user);
  }

  /// Search locally known users by nickname or display name
  /// (V2 USER_DISCOVERY.md §2 — discovery by nickname). Local-First: only
  /// users already known on this device (contacts, scanned profiles) are
  /// returned; global search arrives with P2P gossip in a later sprint.
  Future<List<UserCollection>> searchByNickname(String q) async {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) return [];
    final known = await _store.find(
      filter: Filter.equals('isDeleted', false) &
          Filter.equals('profileVisible', true),
    );
    return known
        .where((u) =>
            u.username.toLowerCase().contains(query) ||
            u.displayName.toLowerCase().contains(query))
        .toList()
      ..sort((a, b) => a.username.toLowerCase().compareTo(
            b.username.toLowerCase(),
          ));
  }

  /// Find a user by the short public id used in `pokatuha://u/<ID>` links
  /// (USER_DISCOVERY.md §1 — first 12 hex chars of the UUID).
  Future<UserCollection?> findByPublicId(String shortId) async {
    final wanted = shortId.trim().toUpperCase();
    if (wanted.isEmpty) return null;
    final all = await _store.find(
      filter: Filter.equals('isDeleted', false),
    );
    for (final u in all) {
      final short = u.id.replaceAll('-', '').substring(0, 12).toUpperCase();
      if (short == wanted) return u;
    }
    return null;
  }
}
