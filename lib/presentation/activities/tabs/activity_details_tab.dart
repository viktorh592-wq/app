/// Activity details tab — summary + lifecycle actions (UC-002..UC-004, BR-005).
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:pokatuha/core/utils/timestamps.dart';
import 'package:pokatuha/database/collections/event_collection.dart';
import 'package:pokatuha/domain/enums/enums.dart';
import 'package:pokatuha/domain/repositories/activity_type_repository.dart';
import 'package:pokatuha/domain/services/service_locator.dart';
import 'package:pokatuha/l10n/app_localizations.dart';
import 'package:pokatuha/presentation/activities/activity_detail_page.dart';
import 'package:pokatuha/presentation/app_view_model.dart';
import 'package:pokatuha/presentation/weather/weather_preview.dart';

class ActivityDetailsTab extends StatelessWidget {
  const ActivityDetailsTab({
    super.key,
    required this.event,
    required this.onAction,
    required this.onChanged,
  });

  final EventCollection event;
  final ValueChanged<EventAction> onAction;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final user = context.read<AppViewModel>().user;
    final isOrganizer = user?.id == event.organizerId;
    final status = EventStatus.values.firstWhere(
      (e) => e.name == event.status,
      orElse: () => EventStatus.preparation,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (event.description.isNotEmpty)
          Text(event.description, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
        FutureBuilder<String>(
          future: _activityLabel(),
          builder: (context, s) => _row(
            context,
            icon: Icons.category_outlined,
            label: l.activityType,
            value: s.data ?? '',
          ),
        ),
        _row(
          context,
          icon: Icons.event_outlined,
          label: l.date,
          value: Timestamps.formatLocalDateTime(event.startAt, 'en'),
        ),
        if (event.meetingPoint != null)
          _row(
            context,
            icon: Icons.place_outlined,
            label: l.meetingPoint,
            value: event.meetingPointLabel ??
                '${event.meetingPoint!.lat.toStringAsFixed(4)}, ${event.meetingPoint!.lng.toStringAsFixed(4)}',
          ),
        if (event.maxParticipants != null)
          _row(
            context,
            icon: Icons.group_outlined,
            label: l.maxParticipants,
            value: '${event.maxParticipants}',
          ),
        const SizedBox(height: 16),
        if (event.meetingPoint != null)
          WeatherPreview(point: event.meetingPoint!),
        const SizedBox(height: 16),
        _actions(context, isOrganizer, status, l),
      ],
    );
  }

  Future<String> _activityLabel() async {
    final types = await serviceLocator<ActivityTypeRepository>().all();
    final match = types.where((t) => t.id == event.activityTypeId).firstOrNull;
    return match?.label ?? event.activityTypeId;
  }

  Widget _row(BuildContext context,
      {required IconData icon, required String label, required String value}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.onSurfaceVariant, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodySmall),
                Text(value, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions(
    BuildContext context,
    bool isOrganizer,
    EventStatus status,
    AppLocalizations l,
  ) {
    switch (status) {
      case EventStatus.archived:
      case EventStatus.cancelled:
        return const SizedBox.shrink();
      case EventStatus.ride:
        if (isOrganizer) {
          return FilledButton.icon(
            onPressed: () {
              onAction(EventAction.finishRide);
              onChanged();
            },
            icon: const Icon(Icons.flag_outlined),
            label: Text(l.finishRide),
          );
        }
        return const SizedBox.shrink();
      default:
        return Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () {
                  onAction(EventAction.join);
                  onChanged();
                },
                icon: const Icon(Icons.check_rounded),
                label: Text(l.join),
              ),
            ),
            const SizedBox(width: 12),
            if (isOrganizer) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    onAction(EventAction.startRide);
                    onChanged();
                  },
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(l.startRide),
                ),
              ),
            ] else ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    onAction(EventAction.leave);
                    onChanged();
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: Text(l.leave),
                ),
              ),
            ],
          ],
        );
    }
  }
}
