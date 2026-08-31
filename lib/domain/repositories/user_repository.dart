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

  /// V3.0.1 — create (or return an existing) "stub" user record for a public
  /// ID discovered through a scanned `pokatuha://u/{ID}` link when the user is
  /// not yet known on this device (USER_DISCOVERY.md §2 — discovery by QR).
  ///
  /// Local-First context: in a server-less, P2P-not-yet-shipped app the only
  /// way to learn about another user is by scanning their QR or being handed
  /// their contact out-of-band. When the scanned user is unknown locally,
  /// previous versions of the app showed "Участник не найден" and gave up,
  /// which made it impossible to invite anyone to a group.
  ///
  /// The stub user is a fully valid [UserCollection] entity:
  ///   • `id` = the 12-char publicId (kept stable so subsequent scans of the
  ///     same QR find the same record instead of creating duplicates)
  ///   • `username` = "user_{publicId}" (lowercase) so nickname search can
  ///     also locate the stub if the inviter types the public id back in
  ///   • `displayName` = "User {first 4 chars}" — minimal placeholder until
  ///     P2P profile exchange is implemented (ADR-002 / Rule 5)
  ///   • `profileVisible` = true so the user appears in nickname searches
  ///
  /// When real P2P profile exchange arrives, the stub record can be merged
  /// into the full profile (matched by the original public id) — same local
  /// id policy so no member-link records need updating.
  Future<UserCollection> getOrCreateStubFromPublicId(String shortId) async {
    final wanted = shortId.trim().toUpperCase();
    if (wanted.isEmpty) {
      throw const BusinessRuleError('Cannot create a stub user: empty id');
    }
    final existing = await findByPublicId(wanted);
    if (existing != null) return existing;

    final now = Timestamps.nowUtc();
    final shortPrefix = wanted.length >= 4 ? wanted.substring(0, 4) : wanted;
    final user = UserCollection()
      ..id = wanted // stable 12-char id; matches findByPublicId's lookup rule
      ..createdAt = now
      ..updatedAt = now
      ..version = 1
      ..isDeleted = false
      ..displayName = 'User $shortPrefix'
      ..username = 'user_${wanted.toLowerCase()}'
      ..bio = null
      ..profileVisible = true
      ..createdBy = null;
    return _store.put(user);
  }
}
