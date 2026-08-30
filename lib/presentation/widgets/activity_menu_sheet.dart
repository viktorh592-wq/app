/// Activity three-dot menu (V2 GROUPS_AND_ACTIVITIES.md §9, FIX_PLAN S2-T8).
/// Exactly seven actions: Edit / Duplicate / Share / Show on map /
/// Pin in group / Archive / Delete. Opened from ActivityCard's more_vert
/// button. The "Show on map" entry was added in Sprint 6 (S6-T6 / S4-T10)
/// to wire the activity card to the standalone Map tab.
import 'package:flutter/material.dart';

import 'package:pokatuha/core/tokens/design_tokens.dart';
import 'package:pokatuha/database/collections/event_collection.dart';
import 'package:pokatuha/l10n/app_localizations.dart';

class ActivityMenuSheet extends StatelessWidget {
  const ActivityMenuSheet({
    super.key,
    required this.event,
    required this.onEdit,
    required this.onDuplicate,
    required this.onShare,
    required this.onShowOnMap,
    required this.onPin,
    required this.onArchive,
    required this.onDelete,
  });

  final EventCollection event;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onShare;

  /// S6-T6 (S4-T10) — opens the standalone MapPage centered on this
  /// activity with its route pre-drawn (FIX_PLAN §S4-T10 step 2).
  final VoidCallback onShowOnMap;

  final VoidCallback onPin;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final errorColor = Theme.of(context).colorScheme.error;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(DesignTokens.space4),
            child: Text(
              event.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: Text(l.menuEdit),
            onTap: () {
              Navigator.pop(context);
              onEdit();
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy_rounded),
            title: Text(l.menuDuplicate),
            onTap: () {
              Navigator.pop(context);
              onDuplicate();
            },
          ),
          ListTile(
            leading: const Icon(Icons.share_outlined),
            title: Text(l.menuShare),
            onTap: () {
              Navigator.pop(context);
              onShare();
            },
          ),
          ListTile(
            leading: const Icon(Icons.map_outlined),
            title: Text(l.menuShowOnMap),
            onTap: () {
              Navigator.pop(context);
              onShowOnMap();
            },
          ),
          ListTile(
            leading: const Icon(Icons.push_pin_outlined),
            title: Text(event.pinnedInGroup ? l.menuUnpin : l.menuPin),
            onTap: () {
              Navigator.pop(context);
              onPin();
            },
          ),
          ListTile(
            leading: const Icon(Icons.archive_outlined),
            title: Text(l.menuArchive),
            onTap: () {
              Navigator.pop(context);
              onArchive();
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: errorColor),
            title: Text(
              l.delete,
              style: TextStyle(color: errorColor),
            ),
            onTap: () {
              Navigator.pop(context);
              onDelete();
            },
          ),
          const SizedBox(height: DesignTokens.space2),
        ],
      ),
    );
  }
}
