import 'package:flutter/material.dart';
import 'package:pokatuha/core/tokens/design_tokens.dart';
import 'package:pokatuha/database/collections/event_collection.dart';
import 'package:pokatuha/domain/enums/enums.dart';
import 'package:pokatuha/l10n/app_localizations.dart';

/// Activity card — pixel-perfect to Figma / screenshots.
/// Uses the activity accent color for the entire card background (V2 §11 —
/// color propagation; FIX_PLAN S2-T7). Shows a pin badge when the activity
/// is pinned in its group (V2 §9).
class ActivityCard extends StatelessWidget {
  final EventCollection event;
  final String activityLabel;
  final int participantCount;
  final VoidCallback onTap;
  final VoidCallback? onMenuTap;
  final Widget? mapPreview;

  const ActivityCard({
    super.key,
    required this.event,
    required this.activityLabel,
    required this.participantCount,
    required this.onTap,
    this.onMenuTap,
    this.mapPreview,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = _accent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: DesignTokens.space4,
          vertical: DesignTokens.space2,
        ),
        decoration: BoxDecoration(
          color: accentColor,
          borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(DesignTokens.space4),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 20,
                    backgroundColor: DesignTokens.limeAccent,
                    child: Icon(
                      Icons.person_outline,
                      color: DesignTokens.textPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: DesignTokens.space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          style: DesignTokens.title(
                              color: DesignTokens.textPrimary),
                        ),
                        Text(
                          activityLabel,
                          style: DesignTokens.caption(
                            color: DesignTokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (event.pinnedInGroup)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        Icons.push_pin_rounded,
                        size: 18,
                        color: DesignTokens.textPrimary.withOpacity(0.7),
                      ),
                    ),
                  if (onMenuTap != null)
                    IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: onMenuTap,
                      color: DesignTokens.textPrimary,
                    ),
                ],
              ),
            ),

            // Map preview
            if (mapPreview != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.space4,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                  child: SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: mapPreview,
                  ),
                ),
              ),

            // Info rows
            Padding(
              padding: const EdgeInsets.all(DesignTokens.space4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(
                      icon: Icons.calendar_today_outlined,
                      text: _formatDate(event.startAt)),
                  const SizedBox(height: DesignTokens.space2),
                  _InfoRow(
                      icon: Icons.location_on_outlined,
                      text: event.meetingPointLabel ?? '—'),
                  const SizedBox(height: DesignTokens.space2),
                  _InfoRow(
                    icon: Icons.people_outline,
                    text: '$participantCount',
                  ),
                  if (event.description.isNotEmpty) ...[
                    const SizedBox(height: DesignTokens.space3),
                    Text(
                      'Описание: ${event.description}',
                      style:
                          DesignTokens.body(color: DesignTokens.textSecondary),
                    ),
                  ],
                ],
              ),
            ),

            // Actions
            Padding(
              padding: const EdgeInsets.all(DesignTokens.space4),
              child: Row(
                children: [
                  _StatusChip(status: _statusLabel(_statusEnum)),
                  const Spacer(),
                  FilledButton(
                    onPressed: onTap,
                    child: Text(AppLocalizations.of(context)!.openMap),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  EventStatus get _statusEnum {
    return EventStatus.values.firstWhere(
      (e) => e.name == event.status,
      orElse: () => EventStatus.preparation,
    );
  }

  String _statusLabel(EventStatus status) {
    return switch (status) {
      EventStatus.preparation => 'Подготовка',
      EventStatus.meeting => 'Сбор',
      EventStatus.ride => 'В пути',
      EventStatus.pause => 'Пауза',
      EventStatus.finished => 'Завершено',
      EventStatus.archived => 'В архиве',
      EventStatus.cancelled => 'Отменено',
    };
  }

  /// Activity accent color (V2 §11): event.accentColor if set, violet
  /// otherwise. Replaces the old status-based card color (FIX_PLAN S2-T7).
  Color get _accent {
    final argb = event.accentColor;
    return argb != null ? Color(argb) : ActivityColors.swatches.first;
  }

  String _formatDate(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: DesignTokens.textPrimary),
        const SizedBox(width: DesignTokens.space3),
        Text(
          text,
          style: DesignTokens.body(color: DesignTokens.textPrimary),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.35),
        borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.access_time, size: 16),
          const SizedBox(width: 8),
          Text(
            status,
            style: DesignTokens.button(),
          ),
        ],
      ),
    );
  }
}
