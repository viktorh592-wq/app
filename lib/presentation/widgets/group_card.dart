/// Group card — list item for the Groups tab (V2 GROUPS_AND_ACTIVITIES.md
/// §5, ARCHITECTURE_V2.md §6). Swipe-to-leave for non-owners.
import 'package:flutter/material.dart';

import 'package:pokatuha/core/tokens/design_tokens.dart';
import 'package:pokatuha/database/collections/group_collection.dart';
import 'package:pokatuha/database/collections/group_member_collection.dart';
import 'package:pokatuha/domain/enums/enums.dart';
import 'package:pokatuha/l10n/app_localizations.dart';

class GroupCard extends StatelessWidget {
  const GroupCard({
    super.key,
    required this.group,
    required this.memberCount,
    required this.myRole,
    required this.onTap,
    this.onLeave,
  });

  final GroupCollection group;
  final int memberCount;
  final GroupMemberCollection? myRole;
  final VoidCallback onTap;
  final VoidCallback? onLeave;

  bool get _isOwner => myRole?.role == GroupRole.owner.name;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final accent = group.defaultAccentColor != null
        ? Color(group.defaultAccentColor!)
        : DesignTokens.primary;
    return Dismissible(
      key: ValueKey('group-card-${group.id}'),
      direction: _isOwner ? DismissDirection.none : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: DesignTokens.space5),
        margin: const EdgeInsets.symmetric(
          horizontal: DesignTokens.space4,
          vertical: DesignTokens.space2,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        ),
        child: Icon(Icons.logout_rounded,
            color: theme.colorScheme.onErrorContainer),
      ),
      confirmDismiss: (_) async {
        onLeave?.call();
        return false; // removal happens via the leave flow
      },
      child: Card(
        margin: const EdgeInsets.symmetric(
          horizontal: DesignTokens.space4,
          vertical: DesignTokens.space2,
        ),
        elevation: 0,
        color: theme.colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
          side: BorderSide(color: accent.withValues(alpha: 0.35)),
        ),
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.space4,
            vertical: DesignTokens.space2,
          ),
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: accent.withValues(alpha: 0.25),
            child: group.name.isEmpty
                ? const Icon(Icons.group_outlined)
                : Text(
                    group.name.substring(0, 1).toUpperCase(),
                    style: DesignTokens.title(color: accent),
                  ),
          ),
          title: Text(
            group.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DesignTokens.bodyMedium(),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: DesignTokens.space1),
              Row(
                children: [
                  Icon(
                    group.type == GroupType.public.name
                        ? Icons.public_rounded
                        : group.type == GroupType.inviteOnly.name
                            ? Icons.mail_rounded
                            : Icons.lock_outline_rounded,
                    size: 14,
                    color: DesignTokens.textSecondary,
                  ),
                  const SizedBox(width: DesignTokens.space1),
                  Expanded(
                    child: Text(
                      l.membersCount(memberCount),
                      style: DesignTokens.caption(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (group.description != null &&
                  group.description!.isNotEmpty) ...[
                const SizedBox(height: DesignTokens.space1),
                Text(
                  group.description!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DesignTokens.pin(),
                ),
              ],
            ],
          ),
          trailing: _isOwner
              ? Icon(Icons.star_rounded, color: accent, size: 20)
              : null,
        ),
      ),
    );
  }
}
