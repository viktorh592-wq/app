/// Groups tab — V2 Group-first home screen (ARCHITECTURE_V2.md §6,
/// GROUPS_AND_ACTIVITIES.md §1). Lists the groups the user belongs to,
/// with a FAB to create a group and a scan action to join by QR.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:pokatuha/core/errors/app_error.dart';
import 'package:pokatuha/core/tokens/design_tokens.dart';
import 'package:pokatuha/database/collections/group_collection.dart';
import 'package:pokatuha/database/collections/group_member_collection.dart';
import 'package:pokatuha/domain/repositories/group_member_repository.dart';
import 'package:pokatuha/domain/repositories/group_repository.dart';
import 'package:pokatuha/domain/services/group_service.dart';
import 'package:pokatuha/domain/services/service_locator.dart';
import 'package:pokatuha/l10n/app_localizations.dart';
import 'package:pokatuha/presentation/app_view_model.dart';
import 'package:pokatuha/presentation/deep_links/deep_link_dispatcher.dart';
import 'package:pokatuha/presentation/groups/create_group_page.dart';
import 'package:pokatuha/presentation/groups/group_detail_page.dart';
import 'package:pokatuha/presentation/users/qr_scanner_page.dart';
import 'package:pokatuha/presentation/widgets/empty_state.dart';
import 'package:pokatuha/presentation/widgets/group_card.dart';
import 'package:pokatuha/presentation/widgets/morphing_fab.dart';
import 'package:pokatuha/presentation/widgets/sync_banner.dart';

class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key});

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  late Future<List<_GroupListItem>> _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() {
    final user = context.read<AppViewModel>().user;
    _future = () async {
      if (user == null) return <_GroupListItem>[];
      // Local-First: the user's groups are the ones they are a member of.
      final groups = await serviceLocator<GroupRepository>().all();
      final members = serviceLocator<GroupMemberRepository>();
      final items = <_GroupListItem>[];
      for (final g in groups) {
        final mine = await members.byGroupAndUser(g.id, user.id);
        if (mine == null) continue;
        final count = await members.countByGroup(g.id);
        items.add(_GroupListItem(group: g, myMembership: mine, count: count));
      }
      return items;
    }();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => setState(_load),
        child: CustomScrollView(
          slivers: [
            SliverAppBar.large(
              title: Text(l.tabGroups),
              actions: [
                IconButton(
                  tooltip: l.scanQr,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  onPressed: () => _scanQr(context),
                ),
                const SizedBox(width: DesignTokens.space2),
              ],
            ),
            const SliverToBoxAdapter(child: SyncBanner()),
            FutureBuilder<List<_GroupListItem>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.group_outlined,
                      title: l.noGroups,
                      subtitle: l.noGroupsHint,
                    ),
                  );
                }
                return SliverList.builder(
                  itemCount: items.length,
                  itemBuilder: (context, i) => GroupCard(
                    group: items[i].group,
                    memberCount: items[i].count,
                    myRole: items[i].myMembership,
                    onTap: () => _open(context, items[i].group.id),
                    onLeave: () => _leave(items[i].group),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: MorphingFab(
        heroTag: 'fab-groups',
        label: l.createGroup,
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const CreateGroupPage()))
            .then((_) => setState(_load)),
      ),
    );
  }

  void _open(BuildContext context, String id) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => GroupDetailPage(groupId: id)))
        .then((_) => setState(_load));
  }

  Future<void> _scanQr(BuildContext context) async {
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScannerPage()),
    );
    if (raw == null || !context.mounted) return;
    await serviceLocator<DeepLinkDispatcher>().handle(raw);
  }

  Future<void> _leave(GroupCollection group) async {
    final l = AppLocalizations.of(context)!;
    final user = context.read<AppViewModel>().user;
    if (user == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.leaveGroup),
        content: Text(group.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l.leave),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await serviceLocator<GroupService>().leaveGroup(group: group, user: user);
      if (mounted) setState(_load);
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}

class _GroupListItem {
  _GroupListItem({
    required this.group,
    required this.myMembership,
    required this.count,
  });

  final GroupCollection group;
  final GroupMemberCollection myMembership;
  final int count;
}
