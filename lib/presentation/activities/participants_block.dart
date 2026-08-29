/// Participants block for the activity Main tab (V2
/// GROUPS_AND_ACTIVITIES.md §13, ARCHITECTURE_V2.md §8, FIX_PLAN S2-T10):
/// a compact row of avatars, the accepted count, the live-position count and
/// — for the organizer — an «Invite» button (V2 USER_DISCOVERY.md §4).
/// Replaces the removed standalone Participants tab.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:pokatuha/core/errors/app_error.dart';
import 'package:pokatuha/core/tokens/design_tokens.dart';
import 'package:pokatuha/database/collections/participant_collection.dart';
import 'package:pokatuha/database/collections/user_collection.dart';
import 'package:pokatuha/domain/enums/enums.dart';
import 'package:pokatuha/domain/repositories/participant_repository.dart';
import 'package:pokatuha/domain/repositories/user_repository.dart';
import 'package:pokatuha/domain/services/service_locator.dart';
import 'package:pokatuha/l10n/app_localizations.dart';
import 'package:pokatuha/presentation/app_view_model.dart';
import 'package:pokatuha/presentation/users/user_search_page.dart';

class ParticipantsBlock extends StatefulWidget {
  const ParticipantsBlock({
    super.key,
    required this.eventId,
    this.showInviteButton = false,
  });

  final String eventId;

  /// Organizer may invite new participants from here (V2 §4).
  final bool showInviteButton;

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
      final participants = await repo.byEvent(widget.eventId);
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

  Future<void> _invite() async {
    final l = AppLocalizations.of(context)!;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserSearchPage(
          title: l.invite,
          onUserSelected: _inviteUser,
        ),
      ),
    );
  }

  Future<void> _inviteUser(UserCollection user) async {
    if (!mounted) return;
    final me = context.read<AppViewModel>().user;
    try {
      await serviceLocator<ParticipantRepository>().invite(
        eventId: widget.eventId,
        userId: user.id,
        byUserId: me?.id,
      );
      if (mounted) {
        setState(_load);
        final l = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.memberAdded(user.displayName))),
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
            if (widget.showInviteButton) ...[
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
