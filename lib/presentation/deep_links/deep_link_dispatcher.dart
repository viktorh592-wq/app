/// Deep link dispatcher — routes parsed pokatuha:// links to screens
/// (FIX_PLAN S1-T7/S1-T10):
///   `pokatuha://u/<id>`    → user profile (if the user is known locally)
///   `pokatuha://g/<code>` → join group by invite code → group details
///   `pokatuha://g/<code>?d=<base64json>` → accept invitation with embedded
///     group payload (V3 fix — materialize the group locally if needed).
/// Owns the app [NavigatorState] key so links can be handled from outside
/// the widget tree (cold start, background links, QR scanner).
import 'package:flutter/material.dart';

import 'package:pokatuha/core/errors/app_error.dart';
import 'package:pokatuha/domain/repositories/user_repository.dart';
import 'package:pokatuha/domain/services/auth_service.dart';
import 'package:pokatuha/domain/services/group_service.dart';
import 'package:pokatuha/domain/services/identity_service.dart';
import 'package:pokatuha/domain/services/service_locator.dart';
import 'package:pokatuha/l10n/app_localizations.dart';
import 'package:pokatuha/presentation/groups/group_detail_page.dart';
import 'package:pokatuha/presentation/users/user_profile_page.dart';

class DeepLinkDispatcher {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Handles a raw URI string (from a deep link or the QR scanner).
  Future<void> handle(String uri) async {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    final l = AppLocalizations.of(context)!;
    final link = serviceLocator<IdentityService>().parse(uri);
    if (link == null) {
      _toast(l.invalidQr);
      return;
    }
    final me = serviceLocator<AuthService>().current;
    if (me == null) return; // not authenticated — ignore until onboarding
    switch (link.kind) {
      case LinkKind.user:
        final user = await serviceLocator<UserRepository>().findByPublicId(
          link.payload,
        );
        if (user == null) {
          _toast(l.userNotFound);
          return;
        }
        _push(UserProfilePage(user: user));
      case LinkKind.group:
        try {
          final groupService = serviceLocator<GroupService>();
          // V3 fix — if the link carries the embedded group payload, use
          // acceptInvitation which can materialize the group locally.
          // Otherwise fall back to the legacy joinByInviteCode path which
          // only works for groups already on this device.
          final group = link.data != null
              ? await groupService.acceptInvitation(
                  user: me, payload: link.data!)
              : await groupService.joinByInviteCode(
                  user: me, code: link.payload);
          _push(GroupDetailPage(groupId: group.id));
        } on AppError catch (e) {
          // Prefer the localized "group not found" message over the raw
          // English error string from the service layer.
          if (e is NotFoundError) {
            _toast(l.groupNotFound);
          } else {
            _toast(e.message);
          }
        }
    }
  }

  void _push(Widget page) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    navigator.push(MaterialPageRoute(builder: (_) => page));
  }

  void _toast(String message) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
