/// Deep link dispatcher — routes parsed pokatuha:// links to screens
/// (FIX_PLAN S1-T7/S1-T10):
///   `pokatuha://u/<id>`    → user profile (if the user is known locally)
///   `pokatuha://g/<code>` → join group by invite code → group details
///   `pokatuha://g/<code>?d=<base64json>` → accept invitation with embedded
///     group payload (V3 fix — materialize the group locally if needed).
/// Owns the app [NavigatorState] key so links can be handled from outside
/// the widget tree (cold start, background links, QR scanner).
import 'dart:async';

import 'package:flutter/material.dart';

import 'package:pokatuha/core/errors/app_error.dart';
import 'package:pokatuha/database/collections/group_collection.dart';
import 'package:pokatuha/domain/repositories/user_repository.dart';
import 'package:pokatuha/domain/services/auth_service.dart';
import 'package:pokatuha/domain/services/chat_sync_service.dart';
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
          // V3.0.4 (bug 2) — repeated scan of a group the user already
          // belongs to must give explicit feedback ("nothing happened"
          // previously). Note: the payload lookup runs BEFORE accept so we
          // can skip the join side effects entirely.
          Map<String, dynamic>? payload = link.data;
          GroupCollection? existing;
          if (payload != null) {
            existing = await groupService.findExistingForInvite(payload);
          }
          if (existing != null && await groupService.isMember(existing.id, me.id)) {
            // Still request chat history — peers may have messages this
            // device missed since the last visit (V3.0.4 bug 1).
            unawaited(
                serviceLocator<ChatSyncService>().requestHistory(existing.id));
            _toast(l.alreadyInGroup);
            _push(GroupDetailPage(groupId: existing.id));
            return;
          }
          // V3 fix — if the link carries the embedded group payload, use
          // acceptInvitation which can materialize the group locally.
          // Otherwise fall back to the legacy joinByInviteCode path which
          // only works for groups already on this device.
          final group = payload != null
              ? await groupService.acceptInvitation(user: me, payload: payload)
              : await groupService.joinByInviteCode(
                  user: me, code: link.payload);
          // V3.0.4 (bug 1) — ask peers on the local network for the recent
          // chat history of the group's activities. Runs fire-and-forget:
          // the group page must open instantly regardless of network state.
          unawaited(
              serviceLocator<ChatSyncService>().requestHistory(group.id));
          _toast(l.groupJoined);
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
