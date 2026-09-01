/// Group service — orchestrates the group lifecycle (V2
/// GROUPS_AND_ACTIVITIES.md §1–§6): creation with auto owner membership,
/// joining by invite code (pokatuha://g/<code>), inviting members and
/// leaving. Local-First: all state lives on the device (ADR-001).
///
/// V3 fix: added [acceptInvitation] — materializes a group from a deep-link
/// payload (received via QR / share link) when the group doesn't yet exist
/// on this device, then adds the current user as a member. This fixes the
/// "group not found on device" bug reported by the user: previously the
/// receiver scanned the QR, looked up the invite code locally, and failed
/// because the group had only ever been created on the inviter's device.
import 'package:pokatuha/core/errors/app_error.dart';
import 'package:pokatuha/database/collections/group_collection.dart';
import 'package:pokatuha/database/collections/group_member_collection.dart';
import 'package:pokatuha/database/collections/user_collection.dart';
import 'package:pokatuha/domain/enums/enums.dart';
import 'package:pokatuha/domain/repositories/group_member_repository.dart';
import 'package:pokatuha/domain/repositories/group_repository.dart';

class GroupService {
  GroupService(this._groupRepository, this._memberRepository);

  final GroupRepository _groupRepository;
  final GroupMemberRepository _memberRepository;

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

  /// Accept a group invitation that carries the full group payload
  /// (V3 fix). If the group already exists on this device (same id or same
  /// invite code), the current user is added as a member and the existing
  /// group is returned. Otherwise the group is created locally from the
  /// payload and the user is added as a member.
  ///
  /// [payload] fields expected (all optional except `id` + `inviteCode`):
  ///   id, name, description, type, ownerId, ownerName, inviteCode,
  ///   defaultAccentColor, discoverable
  Future<GroupCollection> acceptInvitation({
    required UserCollection user,
    required Map<String, dynamic> payload,
  }) async {
    final id = (payload['id'] as String?)?.trim() ?? '';
    final inviteCode = (payload['inviteCode'] as String?)?.trim() ?? '';
    if (id.isEmpty && inviteCode.isEmpty) {
      throw const NotFoundError('Group not found');
    }

    // Try to find an existing local group by id, then by invite code.
    GroupCollection? existing;
    if (id.isNotEmpty) {
      existing = await _groupRepository.getById(id);
    }
    existing ??= inviteCode.isEmpty
        ? null
        : await _groupRepository.getByInviteCode(inviteCode.toUpperCase());

    if (existing != null) {
      // Already on this device — just add the user as a member (idempotent).
      await _memberRepository.addMember(
        groupId: existing.id,
        userId: user.id,
        role: GroupRole.member.name,
        addedBy: user.id,
      );
      return existing;
    }

    // Materialize the group from the payload. Type defaults to public so
    // the receiver can join (private groups would normally be joined via
    // direct member add, but the inviter is sharing a link — treat as
    // public on the receiver side so addMember succeeds).
    final name = (payload['name'] as String?)?.trim() ?? 'Группа';
    final description = payload['description'] as String?;
    final typeStr = (payload['type'] as String?)?.trim() ?? 'public';
    final ownerId = (payload['ownerId'] as String?)?.trim() ?? '';
    final accent = payload['defaultAccentColor'] as int?;

    final group = GroupCollection()
      ..name = name
      ..description = description
      ..type = typeStr
      ..ownerId = ownerId
      ..discoverable = typeStr == GroupType.public.name
      ..defaultAccentColor = accent
      ..createdBy = ownerId
      ..inviteCode = inviteCode.isEmpty ? null : inviteCode.toUpperCase();

    // Preserve the original id so future deep links / sync messages from
    // the inviter can match this group.
    if (id.isNotEmpty) {
      group.id = id;
    }
    final created = await _groupRepository.create(group);

    // Add the current user as a member.
    await _memberRepository.addMember(
      groupId: created.id,
      userId: user.id,
      role: GroupRole.member.name,
      addedBy: user.id,
    );
    return created;
  }

  /// Build the deep-link payload for a group (sent via QR / share link).
  /// The receiver passes this map to [acceptInvitation] to materialize
  /// the group locally.
  Map<String, dynamic> invitationPayload(GroupCollection group) {
    return {
      'id': group.id,
      'name': group.name,
      'description': group.description,
      'type': group.type,
      'ownerId': group.ownerId,
      'inviteCode': group.inviteCode,
      'defaultAccentColor': group.defaultAccentColor,
      'discoverable': group.discoverable,
    };
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
