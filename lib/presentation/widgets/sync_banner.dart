/// Sync / offline banner reflecting the communication mode (Communication.md).
/// Shown when Offline Mode is active or synchronization is pending (UC-005).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:pokatuha/l10n/app_localizations.dart';
import 'package:pokatuha/presentation/app_view_model.dart';

class SyncBanner extends StatelessWidget {
  const SyncBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppViewModel>(
      builder: (context, vm, _) {
        if (!vm.isSyncing) {
          return const SizedBox.shrink();
        }
        final l = AppLocalizations.of(context)!;
        return Material(
          color: Theme.of(context).colorScheme.tertiaryContainer,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l.offlineMode,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                Text(l.syncing, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
        );
      },
    );
  }
}
