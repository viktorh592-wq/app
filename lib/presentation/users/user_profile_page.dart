/// Public user profile page (V2 USER_DISCOVERY.md §4). Actions after
/// finding a user: «Добавить в контакты», «Написать», «Пригласить в группу».
/// Local-First: contacts are marked via user metadata (no new collection);
/// direct messages arrive with the P2P chat in a later sprint.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:pokatuha/core/errors/app_error.dart';
import 'package:pokatuha/core/tokens/design_tokens.dart';
import 'package:pokatuha/database/collections/group_collection.dart';
import 'package:pokatuha/database/collections/user_collection.dart';
import 'package:pokatuha/domain/repositories/group_member_repository.dart';
import 'package:pokatuha/domain/repositories/group_repository.dart';
import 'package:pokatuha/domain/repositories/user_repository.dart';
import 'package:pokatuha/domain/services/group_service.dart';
import 'package:pokatuha/domain/services/identity_service.dart';
import 'package:pokatuha/domain/services/service_locator.dart';
import 'package:pokatuha/l10n/app_localizations.dart';
import 'package:pokatuha/presentation/app_view_model.dart';
import 'package:pokatuha/presentation/groups/group_detail_page.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key, required this.user});

  final UserCollection user;

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  bool _isContact = false;

  @override
  void initState() {
    super.initState();
    _isContact = widget.user.metadata?['isContact'] == true;
  }

  bool get _isMe => widget.user.id == context.read<AppViewModel>().user?.id;

  Future<void> _toggleContact() async {
    final l = AppLocalizations.of(context)!;
    final user = widget.user;
    final meta = Map<String, dynamic>.from(user.metadata ?? {});
    meta['isContact'] = !_isContact;
    user.metadata = meta;
    try {
      await serviceLocator<UserRepository>().updateProfile(user);
      setState(() => _isContact = meta['isContact'] == true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.addedToContacts)),
        );
      }
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  void _writeMessage() {
    final l = AppLocalizations.of(context)!;
    // P2P messaging arrives with the Telegram-style chat sprint
    // (TELEGRAM_STYLE_CHAT.md) — placeholder feedback for now.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.comingSoon)),
    );
  }

  Future<void> _inviteToGroup() async {
    final l = AppLocalizations.of(context)!;
    final me = context.read<AppViewModel>().user;
    if (me == null) return;
    final groups = await serviceLocator<GroupRepository>().all();
    final members = serviceLocator<GroupMemberRepository>();
    final mine = <GroupCollection>[];
    for (final g in groups) {
      final membership = await members.byGroupAndUser(g.id, me.id);
      if (membership == null) continue;
      // Owner/admin can invite (GROUPS_AND_ACTIVITIES.md §4).
      final role = membership.role;
      if (role == 'owner' || role == 'admin') mine.add(g);
    }
    if (!mounted) return;
    if (mine.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.noGroups)),
      );
      return;
    }
    final selected = await showModalBottomSheet<GroupCollection>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(DesignTokens.space4),
              child: Text(l.inviteToGroup,
                  style: Theme.of(sheetContext).textTheme.titleMedium),
            ),
            ...mine.map(
              (g) => ListTile(
                leading: const Icon(Icons.group_outlined),
                title: Text(g.name),
                onTap: () => Navigator.pop(sheetContext, g),
              ),
            ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    try {
      await serviceLocator<GroupService>().inviteMember(
        group: selected,
        user: widget.user,
        addedBy: me.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.memberAdded(widget.user.displayName))),
        );
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => GroupDetailPage(groupId: selected.id),
        ));
      }
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final user = widget.user;
    return Scaffold(
      appBar: AppBar(title: Text(user.displayName)),
      body: ListView(
        padding: const EdgeInsets.all(DesignTokens.space4),
        children: [
          Center(
            child: Column(
              children: [
                // V3.0.2 — show the user's avatar image when available,
                // otherwise fall back to the initial-letter avatar (matches
                // the Profile tab).
                _avatarFor(user, theme),
                const SizedBox(height: DesignTokens.space4),
                Text(user.displayName, style: theme.textTheme.titleLarge),
                if (user.username.isNotEmpty)
                  Text('@${user.username}', style: theme.textTheme.bodyMedium),
                const SizedBox(height: DesignTokens.space2),
                Text(
                  serviceLocator<IdentityService>().userUri(user.id),
                  style: DesignTokens.pin(),
                ),
                if (user.bio != null && user.bio!.isNotEmpty) ...[
                  const SizedBox(height: DesignTokens.space4),
                  Text(user.bio!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium),
                ],
              ],
            ),
          ),
          const SizedBox(height: DesignTokens.space6),
          if (!_isMe) ...[
            FilledButton.icon(
              onPressed: _toggleContact,
              icon: Icon(
                _isContact
                    ? Icons.check_circle_rounded
                    : Icons.person_add_alt_rounded,
              ),
              label: Text(
                _isContact ? l.addedToContacts : l.addToContacts,
              ),
            ),
            const SizedBox(height: DesignTokens.space2),
            OutlinedButton.icon(
              onPressed: _writeMessage,
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              label: Text(l.writeMessage),
            ),
            const SizedBox(height: DesignTokens.space2),
            OutlinedButton.icon(
              onPressed: _inviteToGroup,
              icon: const Icon(Icons.group_add_outlined),
              label: Text(l.inviteToGroup),
            ),
          ],
        ],
      ),
    );
  }

  /// V3.0.2 — avatar with optional image. Falls back to the first-letter
  /// avatar when no image path is set or the file no longer exists.
  Widget _avatarFor(UserCollection user, ThemeData theme) {
    final path = user.avatarPath;
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      return CircleAvatar(
        radius: 44,
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundImage: FileImage(File(path)),
      );
    }
    return CircleAvatar(
      radius: 44,
      backgroundColor: theme.colorScheme.primaryContainer,
      child: Text(
        user.displayName.isEmpty
            ? '?'
            : user.displayName.substring(0, 1).toUpperCase(),
        style: theme.textTheme.headlineMedium,
      ),
    );
  }
}
