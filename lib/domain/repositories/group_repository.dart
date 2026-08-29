/// Group repository (V2 GROUPS_AND_ACTIVITIES.md §1–§4).
/// Enforces soft-delete filtering (Soft_Delete.md).
import 'package:sembast/sembast.dart';

import 'package:pokatuha/core/utils/timestamps.dart';
import 'package:pokatuha/core/utils/uuid.dart';
import 'package:pokatuha/database/collections/group_collection.dart';
import 'package:pokatuha/database/database.dart';
import 'package:pokatuha/domain/enums/enums.dart';

class GroupRepository {
  GroupRepository(this._db);
  final DatabaseService _db;

  TypedStore<GroupCollection> get _store => _db.groupsStore;

  /// All non-deleted groups ordered by last update.
  Future<List<GroupCollection>> all() async => _store.find(
        filter: Filter.equals('isDeleted', false),
        sortOrders: [SortOrder('updatedAt', false)],
      );

  Future<GroupCollection?> getById(String id) async {
    final g = await _store.getById(id);
    return (g != null && !g.isDeleted) ? g : null;
  }

  /// Look up a group by its invite code (pokatuha://g/<code>).
  /// Generated codes are stored upper-case; a fallback scan keeps custom
  /// mixed-case codes findable as well.
  Future<GroupCollection?> getByInviteCode(String code) async {
    final wanted = code.trim();
    if (wanted.isEmpty) return null;
    final list = await _store.find(
      filter: Filter.equals('inviteCode', wanted) &
          Filter.equals('isDeleted', false),
      limit: 1,
    );
    if (list.isNotEmpty) return list.first;
    for (final g in await all()) {
      if (g.inviteCode?.toUpperCase() == wanted.toUpperCase()) return g;
    }
    return null;
  }

  /// Discoverable groups matching a name query (Local-First: only groups
  /// already known on this device).
  Future<List<GroupCollection>> searchByName(String q) async {
    if (q.trim().isEmpty) return [];
    final needle = q.trim().toLowerCase();
    final all = await this.all();
    return all
        .where((g) => g.discoverable && g.name.toLowerCase().contains(needle))
        .toList();
  }

  Future<GroupCollection> create(GroupCollection group) async {
    final now = Timestamps.nowUtc();
    group
      ..id = UuidGenerator.generate()
      ..createdAt = now
      ..updatedAt = now
      ..version = 1
      ..isDeleted = false
      ..type = group.type.isEmpty ? GroupType.private.name : group.type;
    if ((group.inviteCode == null) || group.inviteCode!.isEmpty) {
      group.inviteCode = _generateInviteCode(group.id);
    }
    return _store.put(group);
  }

  Future<GroupCollection> update(GroupCollection group) async {
    group.touch(Timestamps.nowUtc());
    return _store.put(group);
  }

  Future<void> softDelete(GroupCollection group, {String? by}) async {
    group.softDelete(Timestamps.nowUtc(), by: by);
    await _store.put(group);
  }

  /// Short, human-readable invite code derived from the group UUID.
  String _generateInviteCode(String groupId) =>
      groupId.replaceAll('-', '').substring(0, 8).toUpperCase();
}
