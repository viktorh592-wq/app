/// Status chip reflecting the activity lifecycle (Glossary.md — Stage).
/// Localized via AppLocalizations (statusPreparation / statusMeeting /
/// statusRide / statusPause / statusFinished / statusArchived /
/// statusCancelled).
import 'package:flutter/material.dart';

import 'package:pokatuha/domain/enums/enums.dart';
import 'package:pokatuha/l10n/app_localizations.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final EventStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context)!;
    final style = _style(status, scheme, l);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        style.label,
        style: TextStyle(
          color: style.color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  ({String label, Color color}) _style(
    EventStatus s,
    ColorScheme scheme,
    AppLocalizations l,
  ) {
    return switch (s) {
      EventStatus.preparation =>
        (label: l.statusPreparation, color: scheme.primary),
      EventStatus.meeting => (label: l.statusMeeting, color: scheme.tertiary),
      EventStatus.ride => (label: l.statusRide, color: Colors.red),
      EventStatus.pause => (label: l.statusPause, color: scheme.secondary),
      EventStatus.finished =>
        (label: l.statusFinished, color: scheme.outline),
      EventStatus.archived =>
        (label: l.statusArchived, color: scheme.outline),
      EventStatus.cancelled =>
        (label: l.statusCancelled, color: scheme.error),
    };
  }
}
