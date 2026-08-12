import 'package:flutter/material.dart';
import 'package:pokatuha/core/tokens/design_tokens.dart';

/// Activity card — pixel-perfect to Figma / screenshots.
/// Uses activity accent color for the entire card background.
class ActivityCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String date;
  final String distance;
  final int participantCount;
  final String? description;
  final Color accentColor;
  final String status;
  final VoidCallback onOpen;
  final VoidCallback? onMenuTap;
  final Widget? mapPreview;

  const ActivityCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.date,
    required this.distance,
    required this.participantCount,
    this.description,
    required this.accentColor,
    required this.status,
    required this.onOpen,
    this.onMenuTap,
    this.mapPreview,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
                CircleAvatar(
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
                        title,
                        style: DesignTokens.title(color: DesignTokens.textPrimary),
                      ),
                      Text(
                        subtitle,
                        style: DesignTokens.caption(
                          color: DesignTokens.textSecondary,
                        ),
                      ),
                    ],
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
                _InfoRow(icon: Icons.calendar_today_outlined, text: date),
                const SizedBox(height: DesignTokens.space2),
                _InfoRow(icon: Icons.location_on_outlined, text: distance),
                const SizedBox(height: DesignTokens.space2),
                _InfoRow(
                  icon: Icons.people_outline,
                  text: '$participantCount',
                ),
                if (description != null && description!.isNotEmpty) ...[
                  const SizedBox(height: DesignTokens.space3),
                  Text(
                    'Описание: $description',
                    style: DesignTokens.body(color: DesignTokens.textSecondary),
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
                _StatusChip(status: status),
                const Spacer(),
                FilledButton(
                  onPressed: onOpen,
                  child: const Text('Открыть'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
