/// Group service — orchestrates the group lifecycle (V2
/// GROUPS_AND_ACTIVITIES.md §1–§6): creation with auto owner membership,
/// joining by invite code (pokatuha://g/<code>), inviting members and
/// leaving. Local-First: all state lives on the device (ADR-001).
import 'package:pokatuha/core/errors/app_error.dart';
import 'package:pokatuha/database/collections/group_collection.dart';
import 'package:pokatuha/database/collections/group_member_collection.dart';
import 'package:pokatuha/database/collections/user_collection.dart';
import 'package:pokatuha/domain/enums/enums.dart';
import 'package:pokatuha/domain/repositories/group_member_repository.dart';
import 'package:pokatuha/domain/repositories/group_repository.dart';
import 'package:pokatuha/domain/repositories/user_repository.dart';

class GroupService {
  GroupService(this._groupRepository, this._memberRepository, [this._userRepository]);

  final GroupRepository _groupRepository;
  final GroupMemberRepository _memberRepository;

  /// V3.0.1 — Optional [UserRepository] used by `inviteByPublicId` to create a
  /// stub user record on the inviter's device when the scanned public ID does
  /// not match any locally-known user. Injected (not required) so existing
  /// tests that construct `GroupService` with two args keep working.
  final UserRepository? _userRepository;

  /// Create a group (GROUPS_AND_ACTIVITIES.md §3). The owner automatically
  /// joins as a member with the `owner` role (§4).
  Future<GroupCollection> createGroup({
    required UserCollection owner,
    required String name,
    String? description,
    GroupType type = GroupType.private,
    int? defaultAccentColor,
  }) async {
    if (name.trim().isEmpty) {
      throw const BusinessRuleError('Group name is required');
    }
    final group = GroupCollection()
      ..name = name.trim()
      ..description =
          description?.trim().isEmpty == true ? null : description?.trim()
      ..type = type.name
      ..ownerId = owner.id
      ..discoverable = type == GroupType.public
      ..defaultAccentColor = defaultAccentColor
      ..createdBy = owner.id;
    final created = await _groupRepository.create(group);

    // Owner auto-joins as owner role (GROUPS_AND_ACTIVITIES.md §4).
    await _memberRepository.addMember(
      groupId: created.id,
      userId: owner.id,
      role: GroupRole.owner.name,
      addedBy: owner.id,
    );
    return created;
  }

  /// Join a group via its invite code (USER_DISCOVERY.md §2 — invitation
  /// link / QR). Private groups cannot be joined this way.
  Future<GroupCollection> joinByInviteCode({
    required UserCollection user,
    required String code,
  }) async {
    final group = await _groupRepository.getByInviteCode(
      code.trim().toUpperCase(),
    );
    if (group == null) {
      throw const NotFoundError('Group not found');
    }
    if (group.type == GroupType.private.name) {
      throw const BusinessRuleError('Private group — join by invitation only');
    }
    await _memberRepository.addMember(
      groupId: group.id,
      userId: user.id,
      role: GroupRole.member.name,
      addedBy: user.id,
    );
    return group;
  }

  /// Invite a user to a group by nickname-search result / scanned profile
  /// (USER_DISCOVERY.md §4 — «Пригласить в группу»). Enforces the 30-member
  /// cap (ARCHITECTURE_V2.md §3).
  Future<void> inviteMember({
    required GroupCollection group,
    required UserCollection user,
    required String addedBy,
  }) async {
    final existing = await _memberRepository.byGroupAndUser(
      group.id,
      user.id,
    );
    if (existing != null) {
      throw const BusinessRuleError('Already a member');
    }
    final count = await _memberRepository.countByGroup(group.id);
    if (count >= group.maxMembers) {
      throw const BusinessRuleError('Group is full (max 30 members)');
    }
    await _memberRepository.addMember(
      groupId: group.id,
      userId: user.id,
      role: GroupRole.member.name,
      addedBy: addedBy,
    );
  }

  /// V3.0.1 — Invite a user to a group by their short public id (the value
  /// carried in a `pokatuha://u/<ID>` link). When the user is not yet known
  /// on the inviter's device, a stub user record is created via
  /// [UserRepository.getOrCreateStubFromPublicId] so the member appears in
  /// the group's member list immediately (USER_DISCOVERY.md §2 — discovery
  /// by QR, and the user-reported bug: «нет возможности добавить участника
  /// в группу, при наведении курсора на QR-код появляется сообщение
  /// «Участник не найден»»).
  ///
  /// Returns the (existing or stub) [UserCollection] so the UI can show the
  /// localized "member added" snackbar with the user's display name.
  Future<UserCollection> inviteByPublicId({
    required GroupCollection group,
    required String publicId,
    required String addedBy,
  }) async {
    final users = _userRepository;
    if (users == null) {
      throw const BusinessRuleError(
          'UserRepository not wired to GroupService — invite by public id unavailable');
    }
    final user = await users.getOrCreateStubFromPublicId(publicId);
    await inviteMember(group: group, user: user, addedBy: addedBy);
    return user;
  }

  /// Leave a group. The owner must transfer ownership first (§4).
  Future<void> leaveGroup({
    required GroupCollection group,
    required UserCollection user,
  }) async {
    final member = await _memberRepository.byGroupAndUser(group.id, user.id);
    if (member == null) {
      throw const NotFoundError('Not a member');
    }
    if (member.role == GroupRole.owner.name) {
      throw const BusinessRuleError(
          'Owner cannot leave — transfer ownership first');
    }
    await _memberRepository.removeMember(member, by: user.id);
  }

  /// Update group fields (Settings tab — admins only, §5).
  Future<GroupCollection> updateGroup(GroupCollection group) async {
    if (group.name.trim().isEmpty) {
      throw const BusinessRuleError('Group name is required');
    }
    return _groupRepository.update(group);
  }

  /// Delete a group — owner only (§4).
  Future<void> deleteGroup({
    required GroupCollection group,
    required String byUserId,
  }) async {
    if (group.ownerId != byUserId) {
      throw const BusinessRuleError('Only the owner can delete the group');
    }
    await _groupRepository.softDelete(group, by: byUserId);
  }

  /// Membership of a user in a group (null — not a member).
  Future<GroupMemberCollection?> membershipOf(
    String groupId,
    String userId,
  ) =>
      _memberRepository.byGroupAndUser(groupId, userId);

  /// Whether the user may manage the group (owner or admin, §4).
  Future<bool> canManage(String groupId, String userId) async {
    final member = await _memberRepository.byGroupAndUser(groupId, userId);
    if (member == null) return false;
    return member.role == GroupRole.owner.name ||
        member.role == GroupRole.admin.name;
  }
}
