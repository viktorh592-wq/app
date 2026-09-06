/// Group → Members tab (V2 GROUPS_AND_ACTIVITIES.md §5): member list with
/// roles. The «Invite» action is now owned by the parent GroupDetailPage
/// (tab-dependent MorphingFab) — see V3.0.3 fix.
///
/// V3.0.3 fix (user feedback):
///   • Each member row shows the avatar (initials fallback when the avatar
///     image is not available locally), display name and `@nickname` —
///     same fields as the group admin sees. Previously, on the receiver
///     device (after a QR invitation), unknown members were missing from
///     the list because their `UserCollection` records were never
///     materialized; they now come through the invitation payload (see
///     [GroupService.acceptInvitation]).
///   • When the current user is the group admin/owner, tapping a member
///     opens a sheet that lets the admin:
///       - toggle the `canInvite` permission (lets the member invite other
///         users to activities in this group),
///       - promote / demote the member's role (admin ↔ member, owner only).
///   • The owner / admin rows show a badge with the canInvite state so it
///     is visible at a glance which members have the right to invite.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:pokatuha/core/errors/app_error.dart';
import 'package:pokatuha/core/tokens/design_tokens.dart';
import 'package:pokatuha/database/collections/group_collection.dart';
import 'package:pokatuha/database/collections/group_member_collection.dart';
import 'package:pokatuha/database/collections/user_collection.dart';
import 'package:pokatuha/domain/enums/enums.dart';
import 'package:pokatuha/domain/repositories/group_member_repository.dart';
import 'package:pokatuha/domain/repositories/user_repository.dart';
import 'package:pokatuha/domain/services/group_service.dart';
import 'package:pokatuha/domain/services/service_locator.dart';
import 'package:pokatuha/l10n/app_localizations.dart';
import 'package:pokatuha/presentation/app_view_model.dart';
import 'package:pokatuha/presentation/widgets/empty_state.dart';

class GroupMembersTab extends StatefulWidget {
  const GroupMembersTab({
    super.key,
    required this.group,
    this.onChanged,
  });

  final GroupCollection group;
  final VoidCallback? onChanged;

  @override
  State<GroupMembersTab> createState() => _GroupMembersTabState();
}

class _GroupMembersTabState extends State<GroupMembersTab>
    with AutomaticKeepAliveClientMixin {
  late Future<_MembersData> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = () async {
      // Resolve the current user BEFORE the first await — reading from
      // Provider across async gaps is an analyzer error.
      final me = context.read<AppViewModel>().user;
      final members = await serviceLocator<GroupMemberRepository>()
          .byGroup(widget.group.id);
      final users = serviceLocator<UserRepository>();
      final items = <_MemberItem>[];
      for (final m in members) {
        final user = await users.getById(m.userId);
        items.add(_MemberItem(member: m, user: user));
      }
      // Sort: owner first, then admin, then members; within role by name.
      items.sort((a, b) {
        final ra = _roleRank(a.member.role);
        final rb = _roleRank(b.member.role);
        if (ra != rb) return ra - rb;
        final an = a.user?.displayName ?? a.member.userId.substring(0, 6);
        final bn = b.user?.displayName ?? b.member.userId.substring(0, 6);
        return an.toLowerCase().compareTo(bn.toLowerCase());
      });
      // Resolve whether the current user may manage the group (owner or
      // admin) so we can show the tap affordance on member rows.
      final canManage = me == null
          ? false
          : await serviceLocator<GroupService>()
              .canManage(widget.group.id, me.id);
      return _MembersData(items: items, canManage: canManage);
    }();
  }

  int _roleRank(String role) {
    switch (role) {
      case 'owner':
        return 0;
      case 'admin':
        return 1;
      default:
        return 2;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: () async => setState(_load),
      child: FutureBuilder<_MembersData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          if (data.items.isEmpty) {
            return ListView(children: [
              const SizedBox(height: 64),
              EmptyState(
                icon: Icons.people_outline_rounded,
                title: AppLocalizations.of(context)!.noMembers,
              ),
            ]);
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: data.items.length,
            itemBuilder: (context, i) =>
                _buildRow(context, data.items[i], data.canManage),
          );
        },
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    _MemberItem item,
    bool canManage,
  ) {
    final role = GroupRole.values.firstWhere(
      (r) => r.name == item.member.role,
      orElse: () => GroupRole.member,
    );
    final name =
        item.user?.displayName ?? item.member.userId.substring(0, 6);
    final nickname = item.user?.username.isNotEmpty == true
        ? '@${item.user!.username}'
        : null;
    final me = context.read<AppViewModel>().user;
    final isMe = me?.id == item.member.userId;
    final tappable = canManage && !isMe && role != GroupRole.owner;

    return ListTile(
      leading: _avatar(context, item.user, name),
      title: Row(
        children: [
          Expanded(
            child: Text(
              name + (isMe ? ' (Вы)' : ''),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (item.member.canInvite && role == GroupRole.member)
            Padding(
              padding: const EdgeInsets.only(left: DesignTokens.space2),
              child: _inviteBadge(context),
            ),
        ],
      ),
      subtitle: nickname == null ? null : Text(nickname),
      trailing: _roleChip(context, role),
      onTap: tappable ? () => _openMemberSheet(context, item) : null,
    );
  }

  Widget _avatar(BuildContext context, UserCollection? user, String name) {
    final avatarPath = user?.avatarPath;
    if (avatarPath != null && avatarPath.isNotEmpty) {
      final file = File(avatarPath);
      if (file.existsSync()) {
        return CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          backgroundImage: FileImage(file),
        );
      }
    }
    return CircleAvatar(
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Text(
        name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
      ),
    );
  }

  /// Admin / owner sheet — lets the admin toggle the `canInvite`
  /// permission and (owner only) change the member's role.
  void _openMemberSheet(BuildContext context, _MemberItem item) {
    final me = context.read<AppViewModel>().user;
    final isOwner = me != null && me.id == widget.group.ownerId;
    final displayName =
        item.user?.displayName ?? item.member.userId.substring(0, 6);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(DesignTokens.space4),
              child: Row(
                children: [
                  _avatar(context, item.user, displayName),
                  const SizedBox(width: DesignTokens.space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(displayName, style: DesignTokens.title()),
                        if (item.user?.username.isNotEmpty == true)
                          Text('@${item.user!.username}',
                              style: DesignTokens.caption()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // V3.0.3 fix — admin can grant / revoke the invite permission
            // directly from the Members tab.
            SwitchListTile(
              secondary: const Icon(Icons.person_add_alt_1_rounded),
              title: Text(AppLocalizations.of(context)!.canInvite),
              subtitle: Text(AppLocalizations.of(context)!.canInviteHint),
              value: item.member.canInvite,
              onChanged: (v) => _toggleCanInvite(sheetContext, item, v),
            ),
            // V3.0.3 fix — owner can promote / demote admin role.
            if (isOwner && item.member.role != GroupRole.owner.name) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.shield_outlined),
                title: Text(AppLocalizations.of(context)!.roleAdmin),
                trailing: item.member.role == GroupRole.admin.name
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => _setRole(sheetContext, item, GroupRole.admin),
              ),
              ListTile(
                leading: const Icon(Icons.person_outline_rounded),
                title: Text(AppLocalizations.of(context)!.roleMember),
                trailing: item.member.role == GroupRole.member.name
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => _setRole(sheetContext, item, GroupRole.member),
              ),
            ],
            const SizedBox(height: DesignTokens.space2),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleCanInvite(
    BuildContext sheetContext,
    _MemberItem item,
    bool value,
  ) async {
    final me = context.read<AppViewModel>().user;
    if (me == null) return;
    try {
      await serviceLocator<GroupService>().setCanInvite(
        groupId: widget.group.id,
        memberId: item.member.userId,
        canInvite: value,
        byUserId: me.id,
      );
      // Close the sheet first (use the sheet's navigator), then refresh
      // the list. The sheet's navigator is the same as the parent's, but
      // `Navigator.of(sheetContext).pop()` correctly identifies the modal
      // route that's currently on top.
      if (sheetContext.mounted) Navigator.of(sheetContext).pop();
      if (mounted) {
        setState(_load);
        widget.onChanged?.call();
      }
    } on AppError catch (e) {
      if (sheetContext.mounted) {
        ScaffoldMessenger.of(sheetContext)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _setRole(
    BuildContext sheetContext,
    _MemberItem item,
    GroupRole role,
  ) async {
    final me = context.read<AppViewModel>().user;
    if (me == null) return;
    try {
      await serviceLocator<GroupService>().setRole(
        groupId: widget.group.id,
        memberId: item.member.userId,
        role: role,
        byUserId: me.id,
      );
      if (sheetContext.mounted) Navigator.of(sheetContext).pop();
      if (mounted) {
        setState(_load);
        widget.onChanged?.call();
      }
    } on AppError catch (e) {
      if (sheetContext.mounted) {
        ScaffoldMessenger.of(sheetContext)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Widget _roleChip(BuildContext context, GroupRole role) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final label = switch (role) {
      GroupRole.owner => l.roleOwner,
      GroupRole.admin => l.roleAdmin,
      GroupRole.member => l.roleMember,
    };
    final color = switch (role) {
      GroupRole.owner => scheme.primary,
      GroupRole.admin => scheme.tertiary,
      GroupRole.member => scheme.outline,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
      ),
      child: Text(
        label,
        style: DesignTokens.pin(color: color),
      ),
    );
  }

  Widget _inviteBadge(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.tertiary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_add_alt_1_rounded,
              size: 12, color: scheme.tertiary),
          const SizedBox(width: 4),
          Text(
            AppLocalizations.of(context)!.canInviteShort,
            style: DesignTokens.pin(color: scheme.tertiary),
          ),
        ],
      ),
    );
  }
}

class _MembersData {
  _MembersData({required this.items, required this.canManage});
  final List<_MemberItem> items;
  final bool canManage;
}

class _MemberItem {
  _MemberItem({required this.member, this.user});

  final GroupMemberCollection member;
  final UserCollection? user;
}
