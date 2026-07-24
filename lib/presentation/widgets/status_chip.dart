/// Status chip reflecting the activity lifecycle (Glossary.md — Stage).
import 'package:flutter/material.dart';

import 'package:pokatuha/domain/enums/enums.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final EventStatus status;

  @override
  Widget build(BuildContext context) {
    final (:label, :color) = _style(status, Theme.of(context).colorScheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  ({String label, Color color}) _style(EventStatus s, ColorScheme scheme) {
    return switch (s) {
      EventStatus.preparation => (label: 'Preparation', color: scheme.primary),
      EventStatus.meeting => (label: 'Meeting', color: scheme.tertiary),
      EventStatus.ride => (label: 'Live', color: Colors.red),
      EventStatus.pause => (label: 'Pause', color: scheme.secondary),
      EventStatus.finished => (label: 'Finished', color: scheme.outline),
      EventStatus.archived => (label: 'Archived', color: scheme.outline),
      EventStatus.cancelled => (label: 'Cancelled', color: scheme.error),
    };
  }
}
