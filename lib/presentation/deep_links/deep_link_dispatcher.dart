/// Deep link dispatcher — routes parsed pokatuha:// links to screens
/// (FIX_PLAN S1-T7/S1-T10):
///   `pokatuha://u/<id>`    → user profile (if the user is known locally)
///   `pokatuha://g/<code>` → join group by invite code → group details
/// Owns the app [NavigatorState] key so links can be handled from outside
/// the widget tree (cold start, background links, QR scanner).
///
/// V3.0.1 — when a personal `pokatuha://u/<ID>` link is scanned for a user
/// not yet known on this device, a stub [UserCollection] is created via
/// `UserRepository.getOrCreateStubFromPublicId` and the profile page is
/// opened with it (bug fix for the user-reported «Участник не найден»
/// toast that blocked discovery of any new user).
import 'package:flutter/material.dart';

import 'package:pokatuha/core/errors/app_error.dart';
import 'package:pokatuha/database/collections/user_collection.dart';
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
        final users = serviceLocator<UserRepository>();
        final found = await users.findByPublicId(link.payload);
        UserCollection user;
        if (found != null) {
          user = found;
        } else {
          // V3.0.1 — instead of bailing out with «Участник не найден» and
          // blocking discovery of any new user, create a stub record and
          // open the (mostly empty) profile page so the user can still
          // interact (add to contacts, invite to a group, …).
          try {
            user = await users.getOrCreateStubFromPublicId(link.payload);
          } on AppError catch (e) {
            _toast(e.message);
            return;
          }
        }
        _push(UserProfilePage(user: user));
      case LinkKind.group:
        try {
          final group = await serviceLocator<GroupService>()
              .joinByInviteCode(user: me, code: link.payload);
          _push(GroupDetailPage(groupId: group.id));
        } on AppError catch (e) {
          _toast(e.message);
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
