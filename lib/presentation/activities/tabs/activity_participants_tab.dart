/// Participants tab — list participants and their status (FR-003, US-004).
import 'package:flutter/material.dart';

import 'package:pokatuha/core/utils/timestamps.dart';
import 'package:pokatuha/database/collections/participant_collection.dart';
import 'package:pokatuha/domain/enums/enums.dart';
import 'package:pokatuha/domain/repositories/participant_repository.dart';
import 'package:pokatuha/domain/services/service_locator.dart';

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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ParticipantCollection>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snapshot.data!;
        if (list.isEmpty) {
          return const Center(child: Text('No participants yet'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
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
            return ListTile(
              leading: CircleAvatar(
                child: Text(role == ParticipantRole.organizer ? 'O' : 'P'),
              ),
              title: Text('User ${p.userId.substring(0, 6)}'),
              subtitle: Text(
                p.joinedAt != null
                    ? 'Joined ${Timestamps.relativeFromNow(p.joinedAt!, 'en')}'
                    : status.name,
              ),
              trailing: _statusChip(context, status),
            );
          },
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
