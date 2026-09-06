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
///
/// V3.0.3 fix (user feedback): the invitation payload now also carries the
/// list of group members (with their displayName / username / role /
/// canInvite) and the list of activities in the group. The receiver
/// materializes them locally so that:
///   • the «Members» tab on the receiver's device shows all members (not
///     only themselves),
///   • the «Activities» tab on the receiver's device shows all activities
///     regardless of their visibility (public / private / linkOnly).
/// Visibility rules are then enforced at the activity level (who can join,
/// who can invite).
import 'package:pokatuha/core/errors/app_error.dart';
import 'package:pokatuha/core/utils/timestamps.dart';
import 'package:pokatuha/database/collections/embedded/geo_point.dart';
import 'package:pokatuha/database/collections/event_collection.dart';
import 'package:pokatuha/database/collections/group_collection.dart';
import 'package:pokatuha/database/collections/group_member_collection.dart';
import 'package:pokatuha/database/collections/user_collection.dart';
import 'package:pokatuha/domain/enums/enums.dart';
import 'package:pokatuha/domain/repositories/event_repository.dart';
import 'package:pokatuha/domain/repositories/group_member_repository.dart';
import 'package:pokatuha/domain/repositories/group_repository.dart';
import 'package:pokatuha/domain/repositories/participant_repository.dart';
import 'package:pokatuha/domain/repositories/user_repository.dart';

class GroupService {
  GroupService(
    this._groupRepository,
    this._memberRepository,
    this._eventRepository,
    this._userRepository,
    this._participantRepository,
  );

  final GroupRepository _groupRepository;
  final GroupMemberRepository _memberRepository;
  final EventRepository _eventRepository;
  final UserRepository _userRepository;
  final ParticipantRepository _participantRepository;

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

    // Owner auto-joins as owner role (GROUPS_AND_ACTIVITIES.md §4). Owner
    // implicitly has all permissions, including canInvite.
    await _memberRepository.addMember(
      groupId: created.id,
      userId: owner.id,
      role: GroupRole.owner.name,
      addedBy: owner.id,
      canInvite: true,
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
  /// V3.0.3 fix (user feedback): the payload may also include
  ///   - `members` — list of group members with their displayName /
  ///     username / role / canInvite. Unknown users are materialized as
  ///     `UserCollection` records on this device so the Members tab shows
  ///     all members (not only the current user). The current user is
  ///     added/updated as a member (with the role from the payload if
  ///     present, otherwise as `member`).
  ///   - `activities` — list of activities in the group. Unknown activities
  ///     are materialized locally with their original id so they appear in
  ///     the group's Activities tab regardless of their visibility status.
  ///
  /// [payload] fields expected (all optional except `id` + `inviteCode`):
  ///   id, name, description, type, ownerId, inviteCode,
  ///   defaultAccentColor, discoverable,
  ///   members: [{ userId, displayName, username, role, canInvite,
  ///               joinedAt }],
  ///   activities: [{ id, title, description, startAt, activityTypeId,
  ///                  visibility, organizerId, meetingPoint{lat,lng},
  ///                  meetingPointLabel, maxParticipants, accentColor,
  ///                  pinnedInGroup, status }]
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

    final GroupCollection group;
    if (existing != null) {
      group = existing;
    } else {
      // Materialize the group from the payload. Type defaults to public so
      // the receiver can join (private groups would normally be joined via
      // direct member add, but the inviter is sharing a link — treat as
      // public on the receiver side so addMember succeeds).
      final name = (payload['name'] as String?)?.trim() ?? 'Группа';
      final description = payload['description'] as String?;
      final typeStr = (payload['type'] as String?)?.trim() ?? 'public';
      final ownerId = (payload['ownerId'] as String?)?.trim() ?? '';
      final accent = payload['defaultAccentColor'] as int?;

      final newGroup = GroupCollection()
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
        newGroup.id = id;
      }
      group = await _groupRepository.create(newGroup);
    }

    // Materialize members (and their UserCollections) from the payload so
    // the receiver's «Members» tab shows the full roster.
    final membersList = payload['members'];
    if (membersList is List) {
      for (final raw in membersList) {
        if (raw is! Map) continue;
        final m = Map<String, dynamic>.from(raw);
        final userId = (m['userId'] as String?)?.trim() ?? '';
        if (userId.isEmpty) continue;
        final displayName = (m['displayName'] as String?)?.trim() ?? '';
        final username = (m['username'] as String?)?.trim() ?? '';
        final role = (m['role'] as String?)?.trim() ?? GroupRole.member.name;
        final canInvite = m['canInvite'] as bool? ?? false;
        final joinedAt = (m['joinedAt'] as num?)?.toInt();

        // Materialize the UserCollection if not already known on this device.
        final existingUser = await _userRepository.getById(userId);
        if (existingUser == null) {
          final now = Timestamps.nowUtc();
          final u = UserCollection()
            ..id = userId
            ..createdAt = now
            ..updatedAt = now
            ..version = 1
            ..isDeleted = false
            ..displayName = displayName.isEmpty
                ? 'User ${userId.substring(0, 6)}'
                : displayName
            ..username = username.isEmpty
                ? (displayName.isEmpty ? 'user_${userId.substring(0, 6)}'
                    : displayName)
                : username
            ..profileVisible = true;
          await _userRepository.upsertKnown(u);
        }

        // Materialize the group membership (idempotent). Skip the current
        // user — they get added below with the receiver-side role logic.
        if (userId == user.id) continue;
        await _memberRepository.addMember(
          groupId: group.id,
          userId: userId,
          role: role,
          canInvite: canInvite,
          addedBy: group.ownerId,
          joinedAt: joinedAt,
        );
      }
    }

    // Add the current user as a member of the group. For an invitation,
    // they join as a regular member (the owner role is only set on the
    // inviter's device — receiver never claims ownership even if the
    // payload accidentally lists them as owner).
    final existingMembership =
        await _memberRepository.byGroupAndUser(group.id, user.id);
    if (existingMembership == null) {
      await _memberRepository.addMember(
        groupId: group.id,
        userId: user.id,
        role: GroupRole.member.name,
        addedBy: user.id,
      );
    }

    // Materialize activities from the payload so the receiver sees them in
    // the group's «Activities» tab. They are stored with their original id
    // so future sync messages can match them. Visibility rules are
    // enforced at the activity level (who can join / who can invite).
    final activitiesList = payload['activities'];
    if (activitiesList is List) {
      for (final raw in activitiesList) {
        if (raw is! Map) continue;
        final a = Map<String, dynamic>.from(raw);
        final actId = (a['id'] as String?)?.trim() ?? '';
        if (actId.isEmpty) continue;
        final existing = await _eventRepository.getById(actId);
        if (existing != null) continue;

        final organizerId = (a['organizerId'] as String?)?.trim() ?? '';
        final event = EventCollection()
          ..id = actId
          ..groupId = group.id
          ..title = (a['title'] as String?)?.trim() ?? 'Активность'
          ..description = (a['description'] as String?)?.trim() ?? ''
          ..startAt = (a['startAt'] as num?)?.toInt() ?? Timestamps.nowUtc()
          ..activityTypeId =
              (a['activityTypeId'] as String?)?.trim() ?? ''
          ..organizerId = organizerId
          ..visibility = (a['visibility'] as String?)?.trim() ??
              EventVisibility.private.name
          ..maxParticipants = (a['maxParticipants'] as num?)?.toInt()
          ..accentColor = (a['accentColor'] as num?)?.toInt()
          ..pinnedInGroup = a['pinnedInGroup'] as bool? ?? false
          ..status =
              (a['status'] as String?)?.trim() ?? EventStatus.preparation.name
          ..meetingPointLabel = a['meetingPointLabel'] as String?
          ..createdBy = organizerId
          ..createdAt = Timestamps.nowUtc()
          ..updatedAt = Timestamps.nowUtc()
          ..version = 1
          ..isDeleted = false;

        final mp = a['meetingPoint'];
        if (mp is Map) {
          final mpMap = Map<String, dynamic>.from(mp);
          final lat = (mpMap['lat'] as num?)?.toDouble();
          final lng = (mpMap['lng'] as num?)?.toDouble();
          if (lat != null && lng != null) {
            event.meetingPoint = GeoPoint(lat: lat, lng: lng);
          }
        }

        await _eventRepository.upsertFromInvitation(event);

        // Materialize the organizer as an accepted participant of the
        // activity (so the participant count and avatars are correct on
        // the receiver side too). Idempotent.
        if (organizerId.isNotEmpty) {
          final existingP = await _participantRepository.byEventAndUser(
            actId,
            organizerId,
          );
          if (existingP == null) {
            await _participantRepository.invite(
              eventId: actId,
              userId: organizerId,
              role: ParticipantRole.organizer.name,
              byUserId: organizerId,
            );
            final organizerP = await _participantRepository.byEventAndUser(
              actId,
              organizerId,
            );
            if (organizerP != null) {
              await _participantRepository.setStatus(
                organizerP,
                ParticipantStatus.accepted,
              );
            }
          }
        }
      }
    }

    return group;
  }

  /// Build the deep-link payload for a group (sent via QR / share link).
  /// The receiver passes this map to [acceptInvitation] to materialize
  /// the group locally.
  ///
  /// V3.0.3 fix (user feedback): the payload also includes the list of
  /// group members (with displayName / username / role / canInvite) and
  /// the list of activities in the group so the receiver sees the same
  /// roster and activities after joining.
  Future<Map<String, dynamic>> invitationPayload(GroupCollection group) async {
    final members = await _memberRepository.byGroup(group.id);
    final memberPayloads = <Map<String, dynamic>>[];
    for (final m in members) {
      final u = await _userRepository.getById(m.userId);
      memberPayloads.add({
        'userId': m.userId,
        'displayName': u?.displayName ?? '',
        'username': u?.username ?? '',
        'role': m.role,
        'canInvite': m.canInvite,
        'joinedAt': m.joinedAt,
      });
    }

    final activities = await _eventRepository.byGroup(group.id);
    final activityPayloads = <Map<String, dynamic>>[];
    for (final a in activities) {
      activityPayloads.add({
        'id': a.id,
        'title': a.title,
        'description': a.description,
        'startAt': a.startAt,
        'activityTypeId': a.activityTypeId,
        'visibility': a.visibility,
        'organizerId': a.organizerId,
        'meetingPoint': a.meetingPoint?.toMap(),
        'meetingPointLabel': a.meetingPointLabel,
        'maxParticipants': a.maxParticipants,
        'accentColor': a.accentColor,
        'pinnedInGroup': a.pinnedInGroup,
        'status': a.status,
      });
    }

    return {
      'id': group.id,
      'name': group.name,
      'description': group.description,
      'type': group.type,
      'ownerId': group.ownerId,
      'inviteCode': group.inviteCode,
      'defaultAccentColor': group.defaultAccentColor,
      'discoverable': group.discoverable,
      'members': memberPayloads,
      'activities': activityPayloads,
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

  /// V3.0.3 fix (user feedback): whether the user may invite other users
  /// to activities in this group. The owner and admins always can. Regular
  /// members can iff their `canInvite` flag has been granted by an admin
  /// via [grantCanInvite].
  Future<bool> canInviteToActivities(String groupId, String userId) async {
    final member = await _memberRepository.byGroupAndUser(groupId, userId);
    if (member == null) return false;
    if (member.role == GroupRole.owner.name ||
        member.role == GroupRole.admin.name) {
      return true;
    }
    return member.canInvite;
  }

  /// Grant / revoke the `canInvite` permission for a member. Only an
  /// owner or admin may call this.
  Future<void> setCanInvite({
    required String groupId,
    required String memberId,
    required bool canInvite,
    required String byUserId,
  }) async {
    final canManage = await this.canManage(groupId, byUserId);
    if (!canManage) {
      throw const BusinessRuleError(
          'Only the owner or an admin can change member permissions');
    }
    final member = await _memberRepository.byGroupAndUser(groupId, memberId);
    if (member == null) {
      throw const NotFoundError('Member not found');
    }
    await _memberRepository.updatePermissions(
      member,
      canInvite: canInvite,
      by: byUserId,
    );
  }

  /// Promote / demote a member's role (admin / member). Only the owner
  /// may promote to admin.
  Future<void> setRole({
    required String groupId,
    required String memberId,
    required GroupRole role,
    required String byUserId,
  }) async {
    final actor = await _memberRepository.byGroupAndUser(groupId, byUserId);
    if (actor == null || actor.role != GroupRole.owner.name) {
      throw const BusinessRuleError('Only the owner can change roles');
    }
    final member = await _memberRepository.byGroupAndUser(groupId, memberId);
    if (member == null) {
      throw const NotFoundError('Member not found');
    }
    if (member.role == GroupRole.owner.name) {
      throw const BusinessRuleError('Cannot change the owner role');
    }
    await _memberRepository.updatePermissions(
      member,
      role: role.name,
      canInvite: role == GroupRole.admin.name ? true : member.canInvite,
      by: byUserId,
    );
  }
}
