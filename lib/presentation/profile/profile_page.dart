/// Profile tab — local profile (ADR-001) + entries to settings, themes and
/// notifications (FR-010). User controls profile visibility (Privacy rules).
/// Shows the personal QR code (V2 USER_DISCOVERY.md §1–§2) and offers QR
/// scanning for discovery.
///
/// V3.0.2 — tappable avatar with a "change photo" sheet (camera / gallery /
/// remove). The picked image is persisted to the app's documents directory
/// and stored as `UserCollection.avatarPath` (Local-First — no cloud upload).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'package:pokatuha/core/errors/app_error.dart';
import 'package:pokatuha/core/tokens/design_tokens.dart';
import 'package:pokatuha/database/collections/user_collection.dart';
import 'package:pokatuha/domain/repositories/notification_repository.dart';
import 'package:pokatuha/domain/repositories/user_repository.dart';
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
                      GestureDetector(
                        // V3.0.2 — tap avatar to change profile photo. The
                        // sheet offers Camera / Gallery / Remove (when a
                        // photo is set). Disabled when the profile is not
                        // loaded yet so onboarding state does not crash.
                        onTap: user == null
                            ? null
                            : () => _showPhotoSheet(context, user, vm),
                        child: Stack(
                          children: [
                            _Avatar(user: user, radius: 32),
                            // Small camera badge in the bottom-right corner —
                            // signals the avatar is editable. Hidden when no
                            // profile is loaded.
                            if (user != null)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: theme.scaffoldBackgroundColor,
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.camera_alt_rounded,
                                    color: theme.colorScheme.onPrimary,
                                    size: 14,
                                  ),
                                ),
                              ),
                          ],
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

  /// V3.0.2 — bottom sheet with photo options. Picks an image via
  /// `image_picker` (camera or gallery), copies it to the app's documents
  /// directory under `avatars/`, and stores the absolute path in
  /// `UserCollection.avatarPath`. The local [AppViewModel] is refreshed so
  /// the avatar updates immediately.
  Future<void> _showPhotoSheet(
    BuildContext context,
    UserCollection user,
    AppViewModel vm,
  ) async {
    final l = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(DesignTokens.space4),
              child: Text(l.changePhoto,
                  style: Theme.of(sheetContext).textTheme.titleMedium),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: Text(l.photoFromCamera),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickAndSave(context, user, vm, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: Text(l.photoFromGallery),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickAndSave(context, user, vm, ImageSource.gallery);
              },
            ),
            if (user.avatarPath != null && user.avatarPath!.isNotEmpty)
              ListTile(
                leading: Icon(Icons.delete_outline_rounded,
                    color: Theme.of(sheetContext).colorScheme.error),
                title: Text(l.removePhoto),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _removePhoto(context, user, vm);
                },
              ),
            const SizedBox(height: DesignTokens.space2),
          ],
        ),
      ),
    );
  }

  /// Pick an image via [ImagePicker], copy it to `avatars/` in the app's
  /// documents directory, update [UserCollection.avatarPath], persist and
  /// refresh the view model so the avatar updates immediately.
  Future<void> _pickAndSave(
    BuildContext context,
    UserCollection user,
    AppViewModel vm,
    ImageSource source,
  ) async {
    final l = AppLocalizations.of(context)!;
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (xfile == null) return;
      final dir = await getApplicationDocumentsDirectory();
      final target =
          '${dir.path}/avatars/${DateTime.now().millisecondsSinceEpoch}_${xfile.name}';
      await Directory(target).parent.create(recursive: true);
      await File(xfile.path).copy(target);

      // If a previous avatar exists, delete the file so we don't accumulate
      // orphaned files in `avatars/`.
      if (user.avatarPath != null && user.avatarPath!.isNotEmpty) {
        final old = File(user.avatarPath!);
        if (await old.exists()) {
          await old.delete();
        }
      }
      user.avatarPath = target;
      await serviceLocator<UserRepository>().updateProfile(user);
      await vm.refreshProfile();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.photoSaved)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l.photoError}: $e')),
        );
      }
    }
  }

  /// Clear [UserCollection.avatarPath] and delete the saved file.
  Future<void> _removePhoto(
    BuildContext context,
    UserCollection user,
    AppViewModel vm,
  ) async {
    final l = AppLocalizations.of(context)!;
    try {
      final path = user.avatarPath;
      if (path != null && path.isNotEmpty) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      }
      user.avatarPath = null;
      await serviceLocator<UserRepository>().updateProfile(user);
      await vm.refreshProfile();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.photoRemoved)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l.photoError}: $e')),
        );
      }
    }
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

/// V3.0.2 — avatar renderer. Shows the user's photo when [avatarPath] is set,
/// falls back to the first letter of [displayName] otherwise. Same look as
/// the previous inline `CircleAvatar` so the rest of the UI does not need
/// to change.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.user, required this.radius});

  final UserCollection? user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final path = user?.avatarPath;
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundImage: FileImage(File(path)),
      );
    }
    final initial = (user?.displayName.isNotEmpty ?? false)
        ? user!.displayName.substring(0, 1).toUpperCase()
        : '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: theme.colorScheme.primaryContainer,
      child: Text(initial, style: theme.textTheme.headlineSmall),
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
