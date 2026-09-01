/// Group detail — V2 GROUPS_AND_ACTIVITIES.md §5. Exactly four tabs:
/// Activities / Members / Media / Settings (Settings — owner & admin only).
/// FAB inside a group is «Add Activity» (ARCHITECTURE_V2.md §6). The
/// three-dot menu shares the invite link / shows the group QR and offers
/// leaving or deleting the group.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:pokatuha/core/errors/app_error.dart';
import 'package:pokatuha/database/collections/group_collection.dart';
import 'package:pokatuha/domain/repositories/group_repository.dart';
import 'package:pokatuha/domain/services/group_service.dart';
import 'package:pokatuha/domain/services/identity_service.dart';
import 'package:pokatuha/domain/services/service_locator.dart';
import 'package:pokatuha/l10n/app_localizations.dart';
import 'package:pokatuha/presentation/activities/create_activity_page.dart';
import 'package:pokatuha/presentation/app_view_model.dart';
import 'package:pokatuha/presentation/groups/tabs/group_activities_tab.dart';
import 'package:pokatuha/presentation/groups/tabs/group_media_tab.dart';
import 'package:pokatuha/presentation/groups/tabs/group_members_tab.dart';
import 'package:pokatuha/presentation/groups/tabs/group_settings_tab.dart';
import 'package:pokatuha/presentation/widgets/qr_code_dialog.dart';
import 'package:share_plus/share_plus.dart';

class GroupDetailPage extends StatefulWidget {
  const GroupDetailPage({super.key, required this.groupId});

  final String groupId;

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  GroupCollection? _group;
  bool _canManage = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = context.read<AppViewModel>().user;
    final group =
        await serviceLocator<GroupRepository>().getById(widget.groupId);
    final manage = (user == null)
        ? false
        : await serviceLocator<GroupService>()
            .canManage(widget.groupId, user.id);
    // Settings tab is visible to owner/admin only
    // (GROUPS_AND_ACTIVITIES.md §5).
    final tabs = manage ? 4 : 3;
    final previousIndex = _tabController?.index ?? 0;
    final controller = _tabController;
    if (controller == null || controller.length != tabs) {
      controller?.dispose();
      _tabController = TabController(
        length: tabs,
        vsync: this,
        initialIndex: previousIndex.clamp(0, tabs - 1),
      );
    }
    if (mounted) {
      setState(() {
        _group = group;
        _canManage = manage;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (_loading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final group = _group;
    if (group == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l.groupNotFound)),
      );
    }
    final user = context.read<AppViewModel>().user;
    final isOwner = user != null && group.ownerId == user.id;
    final tabController = _tabController!;
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            pinned: true,
            title: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    group.name.isEmpty
                        ? '?'
                        : group.name.substring(0, 1).toUpperCase(),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    group.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: l.showGroupQr,
                icon: const Icon(Icons.qr_code_rounded),
                onPressed: () => _showGroupQr(context, group),
              ),
              PopupMenuButton<String>(
                onSelected: (value) =>
                    _onMenuSelected(context, value, group, isOwner),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'shareLink',
                    child: Row(
                      children: [
                        const Icon(Icons.link_rounded),
                        const SizedBox(width: 12),
                        Text(l.shareInviteLink),
                      ],
                    ),
                  ),
                  if (!isOwner)
                    PopupMenuItem(
                      value: 'leave',
                      child: Row(
                        children: [
                          const Icon(Icons.logout_rounded),
                          const SizedBox(width: 12),
                          Text(l.leaveGroup),
                        ],
                      ),
                    ),
                  if (isOwner)
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete_outline_rounded),
                          const SizedBox(width: 12),
                          Text(l.deleteGroup),
                        ],
                      ),
                    ),
                ],
              ),
            ],
            bottom: TabBar(
              controller: tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: l.tabActivities),
                Tab(text: l.groupMembers),
                Tab(text: l.groupMedia),
                if (_canManage) Tab(text: l.groupSettings),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: tabController,
          children: [
            GroupActivitiesTab(group: group),
            GroupMembersTab(group: group, onChanged: _load),
            GroupMediaTab(group: group),
            if (_canManage) GroupSettingsTab(group: group, onChanged: _load),
          ],
        ),
      ),
      // Inside a group the primary action is «Add Activity»
      // (ARCHITECTURE_V2.md §6).
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(
                builder: (_) => CreateActivityPage(groupId: group.id)))
            .then((_) => _load()),
        icon: const Icon(Icons.add_rounded),
        label: Text(l.createActivity),
      ),
    );
  }

  void _showGroupQr(BuildContext context, GroupCollection group) {
    final l = AppLocalizations.of(context)!;
    final groupService = serviceLocator<GroupService>();
    final identity = serviceLocator<IdentityService>();
    // V3 fix — embed the full group payload in the QR so the receiver can
    // materialize the group even when it doesn't exist on their device yet.
    final uri = identity.groupUriWithPayload(
      inviteCode: group.inviteCode ?? '',
      payload: groupService.invitationPayload(group),
    );
    showDialog(
      context: context,
      builder: (_) => QrCodeDialog(
        title: l.groupQrCode,
        subtitle: group.name,
        uri: uri,
      ),
    );
  }

  Future<void> _onMenuSelected(
    BuildContext context,
    String value,
    GroupCollection group,
    bool isOwner,
  ) async {
    final l = AppLocalizations.of(context)!;
    final user = context.read<AppViewModel>().user;
    switch (value) {
      case 'shareLink':
        final groupService = serviceLocator<GroupService>();
        final identity = serviceLocator<IdentityService>();
        // V3 fix — embed the payload in the shared link too.
        final uri = identity.groupUriWithPayload(
          inviteCode: group.inviteCode ?? '',
          payload: groupService.invitationPayload(group),
        );
        await Share.share(uri);
        break;
      case 'leave':
        if (user == null) return;
        try {
          await serviceLocator<GroupService>()
              .leaveGroup(group: group, user: user);
          if (context.mounted) Navigator.of(context).pop();
        } on AppError catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(e.message)));
          }
        }
        break;
      case 'delete':
        if (user == null) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l.deleteGroup),
            content: Text(l.deleteGroupConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(l.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(l.delete),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        try {
          await serviceLocator<GroupService>()
              .deleteGroup(group: group, byUserId: user.id);
          if (context.mounted) Navigator.of(context).pop();
        } on AppError catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(e.message)));
          }
        }
        break;
    }
  }
}
