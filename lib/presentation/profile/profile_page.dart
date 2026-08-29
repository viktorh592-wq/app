/// Profile tab — local profile (ADR-001) + entries to settings, themes and
/// notifications (FR-010). User controls profile visibility (Privacy rules).
/// Shows the personal QR code (V2 USER_DISCOVERY.md §1–§2) and offers QR
/// scanning for discovery.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:pokatuha/core/tokens/design_tokens.dart';
import 'package:pokatuha/database/collections/user_collection.dart';
import 'package:pokatuha/domain/repositories/notification_repository.dart';
import 'package:pokatuha/domain/services/identity_service.dart';
import 'package:pokatuha/domain/services/service_locator.dart';
import 'package:pokatuha/l10n/app_localizations.dart';
import 'package:pokatuha/presentation/app_view_model.dart';
import 'package:pokatuha/presentation/deep_links/deep_link_dispatcher.dart';
import 'package:pokatuha/presentation/notifications/notifications_page.dart';
import 'package:pokatuha/presentation/settings/settings_page.dart';
import 'package:pokatuha/presentation/settings/themes_page.dart';
import 'package:pokatuha/presentation/users/qr_scanner_page.dart';
import 'package:pokatuha/presentation/widgets/qr_code_dialog.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Consumer<AppViewModel>(
      builder: (context, vm, _) {
        final user = vm.user;
        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar.large(title: Text(l.tabProfile)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Text(
                          (user?.displayName.isNotEmpty ?? false)
                              ? user!.displayName.substring(0, 1).toUpperCase()
                              : '?',
                          style: theme.textTheme.headlineSmall,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user?.displayName ?? '',
                                style: theme.textTheme.titleLarge),
                            if (user?.username.isNotEmpty ?? false)
                              Text('@${user!.username}',
                                  style: theme.textTheme.bodyMedium),
                            if (user?.bio != null && user!.bio!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(user.bio!,
                                    style: theme.textTheme.bodySmall),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: DesignTokens.space4),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: user == null
                              ? null
                              : () => _showMyQr(context, user),
                          icon: const Icon(Icons.qr_code_rounded),
                          label: Text(l.showMyQr),
                        ),
                      ),
                      const SizedBox(width: DesignTokens.space2),
                      FilledButton.tonalIcon(
                        onPressed: () => _scanQr(context),
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        label: Text(l.scanQr),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: DesignTokens.space3),
              ),
              SliverList(
                delegate: SliverChildListDelegate([
                  _entry(
                    context,
                    icon: Icons.settings_outlined,
                    title: l.settings,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const SettingsPage())),
                  ),
                  _entry(
                    context,
                    icon: Icons.palette_outlined,
                    title: l.themes,
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ThemesPage())),
                  ),
                  _entry(
                    context,
                    icon: Icons.notifications_outlined,
                    title: l.notifications,
                    badge: const _UnreadBadge(),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const NotificationsPage())),
                  ),
                ]),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMyQr(BuildContext context, UserCollection user) {
    final l = AppLocalizations.of(context)!;
    final uri = serviceLocator<IdentityService>().userUri(user.id);
    showDialog(
      context: context,
      builder: (_) => QrCodeDialog(
        title: l.yourQrCode,
        subtitle:
            user.username.isEmpty ? user.displayName : '@${user.username}',
        uri: uri,
      ),
    );
  }

  Future<void> _scanQr(BuildContext context) async {
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScannerPage()),
    );
    if (raw == null || !context.mounted) return;
    await serviceLocator<DeepLinkDispatcher>().handle(raw);
  }

  Widget _entry(
    BuildContext context, {
    required IconData icon,
    required String title,
    Widget? badge,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badge != null) badge,
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge();

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AppViewModel>().user?.id;
    if (userId == null) return const SizedBox.shrink();
    return FutureBuilder<int>(
      future: serviceLocator<NotificationRepository>().unreadCount(userId),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        if (count == 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.error,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$count',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onError,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              )),
        );
      },
    );
  }
}
