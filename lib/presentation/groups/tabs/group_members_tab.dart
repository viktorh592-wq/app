/// Group → Members tab (V2 GROUPS_AND_ACTIVITIES.md §5): member list with
/// roles. The «Invite» action is now owned by the parent GroupDetailPage
/// (tab-dependent MorphingFab) — see V3.0.3 fix.
import 'package:flutter/material.dart';

import 'package:pokatuha/core/tokens/design_tokens.dart';
import 'package:pokatuha/database/collections/group_collection.dart';
import 'package:pokatuha/database/collections/group_member_collection.dart';
import 'package:pokatuha/database/collections/user_collection.dart';
import 'package:pokatuha/domain/enums/enums.dart';
import 'package:pokatuha/domain/repositories/group_member_repository.dart';
import 'package:pokatuha/domain/repositories/user_repository.dart';
import 'package:pokatuha/domain/services/service_locator.dart';
import 'package:pokatuha/l10n/app_localizations.dart';
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
  late Future<List<_MemberItem>> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = () async {
      final members = await serviceLocator<GroupMemberRepository>()
          .byGroup(widget.group.id);
      final users = serviceLocator<UserRepository>();
      final items = <_MemberItem>[];
      for (final m in members) {
        final user = await users.getById(m.userId);
        items.add(_MemberItem(member: m, user: user));
      }
      return items;
    }();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l = AppLocalizations.of(context)!;
    // V3.0.3 fix — the «Invite» FAB is now owned by the parent
    // GroupDetailPage (tab-dependent MorphingFab). This tab no longer
    // renders its own Scaffold+FAB — doing so caused a nested-Scaffold
    // conflict where the inner FAB was hidden by the outer one.
    return RefreshIndicator(
      onRefresh: () async => setState(_load),
      child: FutureBuilder<List<_MemberItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return ListView(children: [
              const SizedBox(height: 64),
              EmptyState(
                icon: Icons.people_outline_rounded,
                title: l.noMembers,
              ),
            ]);
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];
              final role = GroupRole.values.firstWhere(
                (r) => r.name == item.member.role,
                orElse: () => GroupRole.member,
              );
              final name = item.user?.displayName ??
                  item.member.userId.substring(0, 6);
              final nickname = item.user?.username.isNotEmpty == true
                  ? '@${item.user!.username}'
                  : null;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
                  ),
                ),
                title: Text(name),
                subtitle: nickname == null ? null : Text(nickname),
                trailing: _roleChip(context, role),
              );
            },
          );
        },
      ),
    );
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
}

class _MemberItem {
  _MemberItem({required this.member, this.user});

  final GroupMemberCollection member;
  final UserCollection? user;
}
