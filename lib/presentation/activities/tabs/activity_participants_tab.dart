/// Participants tab — list participants and their status (FR-003, US-004).
/// The «Invite» action opens local user search and adds the picked user as
/// an invited participant (V2 USER_DISCOVERY.md §4, FIX_PLAN S1-T10).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:pokatuha/core/errors/app_error.dart';
import 'package:pokatuha/core/utils/timestamps.dart';
import 'package:pokatuha/database/collections/participant_collection.dart';
import 'package:pokatuha/database/collections/user_collection.dart';
import 'package:pokatuha/domain/enums/enums.dart';
import 'package:pokatuha/domain/repositories/participant_repository.dart';
import 'package:pokatuha/domain/repositories/user_repository.dart';
import 'package:pokatuha/domain/services/service_locator.dart';
import 'package:pokatuha/l10n/app_localizations.dart';
import 'package:pokatuha/presentation/app_view_model.dart';
import 'package:pokatuha/presentation/users/user_search_page.dart';

class ActivityParticipantsTab extends StatefulWidget {
  const ActivityParticipantsTab({super.key, required this.eventId});

  final String eventId;

  @override
  State<ActivityParticipantsTab> createState() =>
      _ActivityParticipantsTabState();
}

class _ActivityParticipantsTabState extends State<ActivityParticipantsTab> {
  late Future<List<ParticipantCollection>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = serviceLocator<ParticipantRepository>().byEvent(widget.eventId);
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _invite,
        icon: const Icon(Icons.person_add_rounded),
        label: Text(l.invite),
      ),
      body: FutureBuilder<List<ParticipantCollection>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snapshot.data!;
          if (list.isEmpty) {
            return Center(child: Text(l.noMembers));
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final p = list[i];
              final status = ParticipantStatus.values.firstWhere(
                (e) => e.name == p.status,
                orElse: () => ParticipantStatus.invited,
              );
              final role = ParticipantRole.values.firstWhere(
                (e) => e.name == p.role,
                orElse: () => ParticipantRole.member,
              );
              return _participantTile(context, p, role, status);
            },
          );
        },
      ),
    );
  }

  Widget _participantTile(
    BuildContext context,
    ParticipantCollection p,
    ParticipantRole role,
    ParticipantStatus status,
  ) {
    return FutureBuilder<UserCollection?>(
      future: serviceLocator<UserRepository>().getById(p.userId),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final name = user?.displayName ?? 'User ${p.userId.substring(0, 6)}';
        return ListTile(
          leading: CircleAvatar(
            child: Text(role == ParticipantRole.organizer ? 'O' : 'P'),
          ),
          title: Text(name),
          subtitle: Text(
            p.joinedAt != null
                ? 'Joined ${Timestamps.relativeFromNow(p.joinedAt!, 'en')}'
                : status.name,
          ),
          trailing: _statusChip(context, status),
        );
      },
    );
  }

  Widget _statusChip(BuildContext context, ParticipantStatus status) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (status) {
      ParticipantStatus.accepted => scheme.primary,
      ParticipantStatus.invited => scheme.outline,
      ParticipantStatus.declined => scheme.error,
      ParticipantStatus.left => scheme.outline,
      ParticipantStatus.removed => scheme.error,
    };
    return Chip(
      label: Text(status.name),
      labelStyle: TextStyle(color: color, fontSize: 12),
      backgroundColor: color.withValues(alpha: 0.14),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}
