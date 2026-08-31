/// Group → Members tab (V2 GROUPS_AND_ACTIVITIES.md §5): member list with
/// roles + the «Invite» action (USER_DISCOVERY.md §2, §4): show group QR,
/// share the invite link, or find a user by nickname.
///
/// V3.0.1 — added a fourth invite action: «Scan user QR» (bug fix for the
/// user-reported "Участник не найден" issue). Scanning another user's
/// personal `pokatuha://u/<ID>` QR now creates a stub user record on the
/// inviter's device and adds them to the group, instead of showing the
/// "user not found" toast.
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
import 'package:pokatuha/domain/services/identity_service.dart';
import 'package:pokatuha/domain/services/service_locator.dart';
import 'package:pokatuha/l10n/app_localizations.dart';
import 'package:pokatuha/presentation/app_view_model.dart';
import 'package:pokatuha/presentation/users/qr_scanner_page.dart';
import 'package:pokatuha/presentation/users/user_search_page.dart';
import 'package:pokatuha/presentation/widgets/empty_state.dart';
import 'package:pokatuha/presentation/widgets/qr_code_dialog.dart';
import 'package:share_plus/share_plus.dart';

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
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showInviteSheet(context, widget.group),
        icon: const Icon(Icons.person_add_rounded),
        label: Text(l.invite),
      ),
      body: RefreshIndicator(
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

  /// Invite bottom sheet (USER_DISCOVERY.md §2): group QR, invite link,
  /// nickname search (FIX_PLAN S1-T10), and — V3.0.1 — scan a user's
  /// personal QR to invite them (bug fix for «Участник не найден»).
  void _showInviteSheet(BuildContext context, GroupCollection group) {
    final l = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.qr_code_rounded),
              title: Text(l.showGroupQr),
              onTap: () {
                Navigator.pop(sheetContext);
                _showGroupQr(context, group);
              },
            ),
            ListTile(
              leading: const Icon(Icons.link_rounded),
              title: Text(l.shareInviteLink),
              onTap: () {
                Navigator.pop(sheetContext);
                final uri = serviceLocator<IdentityService>()
                    .groupUri(group.inviteCode ?? '');
                Share.share(uri);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_search_rounded),
              title: Text(l.searchByNickname),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => UserSearchPage(
                    onUserSelected: (user) => _inviteUser(context, group, user),
                  ),
                ));
              },
            ),
            // V3.0.1 — invite by scanning the user's personal QR code. The
            // other user shows their personal `pokatuha://u/<ID>` QR (Profile
            // tab → Show my QR); the inviter scans it from this sheet.
            // Scanning a non-user QR (group invite, random link) is rejected
            // with the localized "invalidQr" message and does not add
            // anyone to the group.
            ListTile(
              leading: const Icon(Icons.qr_code_scanner_rounded),
              title: Text(l.scanUserQrToInvite),
              onTap: () {
                Navigator.pop(sheetContext);
                _scanUserQr(context, group);
              },
            ),
            const SizedBox(height: DesignTokens.space2),
          ],
        ),
      ),
    );
  }

  /// V3.0.1 — open the QR scanner to capture another user's personal QR and
  /// invite them to the group. Mirrors `_scanQr` on the Profile page, but
  /// routes the parsed link through `GroupService.inviteByPublicId` instead
  /// of `DeepLinkDispatcher.handle` (the latter would open a profile page,
  /// not add a member).
  Future<void> _scanUserQr(
    BuildContext context,
    GroupCollection group,
  ) async {
    final l = AppLocalizations.of(context)!;
    final me = context.read<AppViewModel>().user;
    if (me == null) return;
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScannerPage()),
    );
    if (raw == null || !context.mounted) return;
    final link = serviceLocator<IdentityService>().parse(raw);
    if (link == null || link.kind != LinkKind.user) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.invalidQr)),
        );
      }
      return;
    }
    try {
      final user = await serviceLocator<GroupService>().inviteByPublicId(
        group: group,
        publicId: link.payload,
        addedBy: me.id,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.memberAdded(user.displayName))),
        );
      }
      widget.onChanged?.call();
      if (mounted) setState(_load);
    } on AppError catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l.inviteFailed}: $e')),
        );
      }
    }
  }

  void _showGroupQr(BuildContext context, GroupCollection group) {
    final l = AppLocalizations.of(context)!;
    final uri =
        serviceLocator<IdentityService>().groupUri(group.inviteCode ?? '');
    showDialog(
      context: context,
      builder: (_) => QrCodeDialog(
        title: l.groupQrCode,
        subtitle: group.name,
        uri: uri,
      ),
    );
  }

  Future<void> _inviteUser(
    BuildContext context,
    GroupCollection group,
    UserCollection user,
  ) async {
    final l = AppLocalizations.of(context)!;
    final me = context.read<AppViewModel>().user;
    if (me == null) return;
    try {
      await serviceLocator<GroupService>().inviteMember(
        group: group,
        user: user,
        addedBy: me.id,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.memberAdded(user.displayName))),
        );
      }
      widget.onChanged?.call();
      if (mounted) setState(_load);
    } on AppError catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}

class _MemberItem {
  _MemberItem({required this.member, this.user});

  final GroupMemberCollection member;
  final UserCollection? user;
}
