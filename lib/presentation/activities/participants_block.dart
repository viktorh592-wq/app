/// Participants block for the activity Main tab (V2
/// GROUPS_AND_ACTIVITIES.md §13, ARCHITECTURE_V2.md §8, FIX_PLAN S2-T10):
/// a compact row of avatars, the accepted count, the live-position count and
/// — for the organizer — an «Invite» button (V2 USER_DISCOVERY.md §4).
/// Replaces the removed standalone Participants tab.
///
/// V3.0.3 fix (user feedback):
///   • The «Invite» button is shown iff the current user has the right to
///     invite to activities in this group (owner / admin / a member who has
///     been explicitly granted the `canInvite` permission by a group admin)
///     AND the activity is not public (public activities are joined via
///     the «Присоединиться» button — inviting is not needed).
///   • Tapping the «Invite» button opens the [GroupMemberPickerPage] which
///     shows only members of the activity's group (not the full local user
///     database). The inviter picks one or several members from the list;
///     each picked member gets a `ParticipantCollection` with status =
///     `invited`.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:pokatuha/core/errors/app_error.dart';
import 'package:pokatuha/core/tokens/design_tokens.dart';
import 'package:pokatuha/database/collections/event_collection.dart';
import 'package:pokatuha/database/collections/participant_collection.dart';
import 'package:pokatuha/database/collections/user_collection.dart';
import 'package:pokatuha/domain/enums/enums.dart';
import 'package:pokatuha/domain/repositories/participant_repository.dart';
import 'package:pokatuha/domain/repositories/user_repository.dart';
import 'package:pokatuha/domain/services/group_service.dart';
import 'package:pokatuha/domain/services/service_locator.dart';
import 'package:pokatuha/l10n/app_localizations.dart';
import 'package:pokatuha/presentation/app_view_model.dart';
import 'package:pokatuha/presentation/groups/group_member_picker_page.dart';

class ParticipantsBlock extends StatefulWidget {
  const ParticipantsBlock({
    super.key,
    required this.event,
    this.showInviteButton = false,
    this.canInvite = false,
  });

  /// Full event (V3.0.3 fix — we need `groupId` and `visibility` to drive
  /// the invite / join UI).
  final EventCollection event;

  /// Organizer may invite new participants from here (V2 §4).
  final bool showInviteButton;

  /// Whether the current user has the `canInvite` permission in this
  /// group (V3.0.3 fix — granted by the group admin via the Members tab).
  /// Owner / admin implicitly have this permission.
  final bool canInvite;

  @override
  State<ParticipantsBlock> createState() => _ParticipantsBlockState();
}

class _ParticipantsBlockState extends State<ParticipantsBlock> {
  static const _maxAvatars = 8;

  late Future<_ParticipantsData> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = () async {
      final repo = serviceLocator<ParticipantRepository>();
      final users = serviceLocator<UserRepository>();
      final participants = await repo.byEvent(widget.event.id);
      final accepted = participants
          .where((p) => p.status == ParticipantStatus.accepted.name)
          .toList();
      final names = <String, String>{};
      for (final p in accepted) {
        final u = await users.getById(p.userId);
        names[p.userId] = u?.displayName ?? 'User ${p.userId.substring(0, 6)}';
      }
      final liveCount =
          accepted.where((p) => p.lastLat != null && p.lastLng != null).length;
      return _ParticipantsData(
        participants: accepted,
        names: names,
        liveCount: liveCount,
      );
    }();
  }

  /// V3.0.3 fix — open the group member picker (only members of the
  /// activity's group are listed). For each selected user, create a
  /// participant record with status = `invited` (idempotent).
  Future<void> _invite() async {
    final groupId = widget.event.groupId;
    if (groupId == null || groupId.isEmpty) return;
    await openGroupMemberPicker(
      context,
      groupId: groupId,
      eventId: widget.event.id,
      onMembersSelected: _inviteUsers,
    );
  }

  Future<void> _inviteUsers(List<UserCollection> users) async {
    if (!mounted || users.isEmpty) return;
    final me = context.read<AppViewModel>().user;
    try {
      for (final user in users) {
        await serviceLocator<ParticipantRepository>().invite(
          eventId: widget.event.id,
          userId: user.id,
          byUserId: me?.id,
        );
      }
      if (mounted) {
        setState(_load);
        final l = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.memberAdded(users.first.displayName))),
        );
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
    // V3.0.3 fix — invite button visibility:
    //   • organizer / admin / canInvite: may invite to non-public activities
    //   • public activities: any group member joins themselves via «Join»,
    //     so the invite button is hidden (inviting is redundant).
    final visibility = EventVisibility.values.firstWhere(
      (v) => v.name == widget.event.visibility,
      orElse: () => EventVisibility.private,
    );
    final canShowInvite = (widget.showInviteButton || widget.canInvite) &&
        visibility != EventVisibility.public;
    return FutureBuilder<_ParticipantsData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 56,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final data = snapshot.data!;
        if (data.participants.isEmpty) {
          return Row(
            children: [
              const Icon(Icons.group_outlined, size: 20),
              const SizedBox(width: DesignTokens.space2),
              Expanded(child: Text(l.noParticipants)),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ...data.participants.take(_maxAvatars).map((p) {
                  final name = data.names[p.userId] ?? '?';
                  return Padding(
                    padding: const EdgeInsets.only(right: DesignTokens.space2),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: DesignTokens.chipLavender,
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: DesignTokens.button(),
                      ),
                    ),
                  );
                }),
                if (data.participants.length > _maxAvatars)
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: DesignTokens.chipLavender,
                    child: Text(
                      '+${data.participants.length - _maxAvatars}',
                      style: DesignTokens.pin(),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: DesignTokens.space3),
            Text(
              data.liveCount > 0
                  ? '${data.participants.length} · ${l.participants} · ${l.liveSharingCount(data.liveCount)}'
                  : '${data.participants.length} · ${l.participants}',
              style: DesignTokens.caption(),
            ),
            if (canShowInvite) ...[
              const SizedBox(height: DesignTokens.space3),
              OutlinedButton.icon(
                onPressed: _invite,
                icon: const Icon(Icons.person_add_rounded, size: 18),
                label: Text(l.invite),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ParticipantsData {
  _ParticipantsData({
    required this.participants,
    required this.names,
    required this.liveCount,
  });

  final List<ParticipantCollection> participants;
  final Map<String, String> names;
  final int liveCount;
}

/// Resolve whether the current user may invite new participants to
/// activities in the given group (V3.0.3 fix). Used by
/// [ActivityDetailsTab] to decide whether to show the «Invite» button.
Future<bool> canCurrentUserInviteToGroup(String groupId, String userId) async {
  return serviceLocator<GroupService>().canInviteToActivities(groupId, userId);
}
