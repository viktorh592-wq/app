/// Group member repository (V2 GROUPS_AND_ACTIVITIES.md §4).
/// Membership link User ↔ Group with role; soft-delete on leave/remove.
import 'package:sembast/sembast.dart';

import 'package:pokatuha/core/utils/timestamps.dart';
import 'package:pokatuha/core/utils/uuid.dart';
import 'package:pokatuha/database/collections/group_member_collection.dart';
import 'package:pokatuha/database/database.dart';

class GroupMemberRepository {
  GroupMemberRepository(this._db);
  final DatabaseService _db;

  TypedStore<GroupMemberCollection> get _store => _db.groupMembersStore;

  Future<List<GroupMemberCollection>> byGroup(String groupId) async =>
      _store.find(
        filter: Filter.equals('groupId', groupId) &
            Filter.equals('isDeleted', false),
        sortOrders: [SortOrder('joinedAt')],
      );

  Future<GroupMemberCollection?> byGroupAndUser(
    String groupId,
    String userId,
  ) async {
    final list = await _store.find(
      filter: Filter.equals('groupId', groupId) &
          Filter.equals('userId', userId) &
          Filter.equals('isDeleted', false),
      limit: 1,
    );
    return list.isEmpty ? null : list.first;
  }

  /// All group memberships of a user (their group list).
  Future<List<GroupMemberCollection>> byUser(String userId) async =>
      _store.find(
        filter:
            Filter.equals('userId', userId) & Filter.equals('isDeleted', false),
        sortOrders: [SortOrder('joinedAt', false)],
      );

  Future<int> countByGroup(String groupId) async => _store.count(
        filter: Filter.equals('groupId', groupId) &
            Filter.equals('isDeleted', false),
      );

  /// Add a member. Idempotent: returns the existing membership if present.
  Future<GroupMemberCollection> addMember({
    required String groupId,
    required String userId,
    String role = 'member',
    String? addedBy,
  }) async {
    final existing = await byGroupAndUser(groupId, userId);
    if (existing != null) return existing;
    final now = Timestamps.nowUtc();
    final member = GroupMemberCollection()
      ..id = UuidGenerator.generate()
      ..createdAt = now
      ..updatedAt = now
      ..version = 1
      ..isDeleted = false
      ..groupId = groupId
      ..userId = userId
      ..role = role
      ..addedBy = addedBy
      ..joinedAt = now
      ..createdBy = addedBy;
    return _store.put(member);
  }

  /// Soft-delete a membership (leave / remove).
  Future<void> removeMember(
    GroupMemberCollection member, {
    String? by,
  }) async {
    member.softDelete(Timestamps.nowUtc(), by: by);
    await _store.put(member);
  }
}
