/// Activity card used in Home and Activities lists (FR-001 fields).
import 'package:flutter/material.dart';

import 'package:pokatuha/core/utils/timestamps.dart';
import 'package:pokatuha/database/collections/event_collection.dart';
import 'package:pokatuha/domain/enums/enums.dart';
import 'package:pokatuha/presentation/widgets/status_chip.dart';

class ActivityCard extends StatelessWidget {
  const ActivityCard({
    super.key,
    required this.event,
    required this.activityLabel,
    this.participantCount,
    this.onTap,
  });

  final EventCollection event;
  final String activityLabel;
  final int? participantCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = EventStatus.values.firstWhere(
      (e) => e.name == event.status,
      orElse: () => EventStatus.preparation,
    );
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      event.title,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusChip(status: status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.category_outlined,
                      size: 16, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(activityLabel, style: theme.textTheme.bodyMedium),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.event_outlined,
                      size: 16, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    Timestamps.formatLocalDateTime(event.startAt, 'en'),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
              if (participantCount != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.group_outlined,
                        size: 16, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text('$participantCount',
                        style: theme.textTheme.bodyMedium),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
