/// Polls tab — create and vote on polls (FR-007). Single / multiple choice,
/// custom options, deadline, editable polls. Progress bars, radio buttons
/// and vote buttons use the activity accent color (V2 §11 — propagation,
/// FIX_PLAN S2-T7).
///
/// V3 Sprint 5 (FIX_PLAN S5-T3..T4) — extended to support V2 POLLS.md:
///   • §3 visibility selector (anonymous / public) in the create sheet
///   • §4 deadline picker; auto-close when deadline passed (PollRepository)
///   • §5 closed-state final-results view (no vote UI, "Closed" badge)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:pokatuha/core/errors/app_error.dart';
import 'package:pokatuha/core/tokens/design_tokens.dart';
import 'package:pokatuha/database/collections/poll_collection.dart';
import 'package:pokatuha/domain/enums/enums.dart';
import 'package:pokatuha/domain/repositories/poll_repository.dart';
import 'package:pokatuha/domain/repositories/participant_repository.dart';
import 'package:pokatuha/domain/services/service_locator.dart';
import 'package:pokatuha/l10n/app_localizations.dart';
import 'package:pokatuha/presentation/app_view_model.dart';

class ActivityPollsTab extends StatefulWidget {
  const ActivityPollsTab({super.key, required this.eventId, this.accentColor});

  final String eventId;

  /// Activity accent color (V2 §11).
  final Color? accentColor;

  @override
  State<ActivityPollsTab> createState() => _ActivityPollsTabState();
}

class _ActivityPollsTabState extends State<ActivityPollsTab> {
  late Future<List<PollCollection>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = serviceLocator<PollRepository>().byEvent(widget.eventId);
  }

  void _openCreate(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CreatePollSheet(eventId: widget.eventId),
    ).then((created) {
      if (created == true) setState(_load);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openCreate(context),
        child: const Icon(Icons.poll_rounded),
      ),
      body: FutureBuilder<List<PollCollection>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final polls = snapshot.data!;
          if (polls.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.poll_outlined, size: 56),
                    const SizedBox(height: 12),
                    Text(l.noPollsYet),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => _openCreate(context),
                      icon: const Icon(Icons.add_rounded),
                      label: Text(l.addPoll),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: polls.length,
            itemBuilder: (context, i) => _PollCard(
              poll: polls[i],
              eventId: widget.eventId,
              accentColor: widget.accentColor,
              onChanged: () => setState(_load),
            ),
          );
        },
      ),
    );
  }
}

class _PollCard extends StatefulWidget {
  const _PollCard({
    required this.poll,
    required this.eventId,
    required this.onChanged,
    this.accentColor,
  });

  final PollCollection poll;
  final String eventId;
  final VoidCallback onChanged;

  /// Activity accent color (V2 §11).
  final Color? accentColor;

  @override
  State<_PollCard> createState() => _PollCardState();
}

class _PollCardState extends State<_PollCard> {
  late PollCollection _poll;
  final _selected = <String>{};

  @override
  void initState() {
    super.initState();
    _poll = widget.poll;
  }

  Future<void> _vote() async {
    if (_selected.isEmpty) return;
    final user = context.read<AppViewModel>().user!;
    final participant = await serviceLocator<ParticipantRepository>()
        .byEventAndUser(widget.eventId, user.id);
    if (participant == null) return;
    try {
      await serviceLocator<PollRepository>().vote(
        poll: _poll,
        participantId: participant.id,
        userId: user.id,
        optionIds: _selected.toList(),
      );
      widget.onChanged();
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _close() async {
    try {
      await serviceLocator<PollRepository>().close(_poll);
      widget.onChanged();
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    final accent = widget.accentColor ?? DesignTokens.primary;
    final type = _poll.type == PollType.multipleChoice.name
        ? PollType.multipleChoice
        : PollType.singleChoice;
    final visibility = _poll.visibility == PollVisibility.anonymous.name
        ? PollVisibility.anonymous
        : PollVisibility.public;
    final isOpen = _poll.status == PollStatus.open.name;
    final total = _poll.options.fold<int>(0, (s, o) => s + o.voteCount);
    final canClose = isOpen &&
        _poll.createdByParticipantId != null &&
        context.read<AppViewModel>().user != null;

    // V2 POLLS.md §5 — closed-state shows only final tallies.
    // Open state shows radio/checkbox selection + accent progress bars.
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child:
                      Text(_poll.question, style: theme.textTheme.titleMedium),
                ),
                // V2 §5 — Closed badge replaces the type label when closed.
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isOpen
                        ? accent.withValues(alpha: 0.18)
                        : theme.colorScheme.errorContainer.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
                  ),
                  child: Text(
                    !isOpen
                        ? l.pollClosed
                        : type == PollType.singleChoice
                            ? l.singleChoice
                            : l.multipleChoice,
                    style: theme.textTheme.labelSmall,
                  ),
                ),
              ],
            ),
            // V2 §3 — visibility label.
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  visibility == PollVisibility.anonymous
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 14,
                  color: DesignTokens.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  visibility == PollVisibility.anonymous
                      ? l.pollAnonymous
                      : l.pollPublic,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: DesignTokens.textSecondary),
                ),
                // V2 §4 — deadline indicator on the card.
                if (_poll.deadlineAt != null) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.schedule_rounded,
                      size: 14, color: DesignTokens.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    _deadlineLabel(l),
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: DesignTokens.textSecondary),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            ..._poll.options.map((o) {
              final pct = total == 0 ? 0 : (o.voteCount / total * 100).round();
              final selected = _selected.contains(o.id);
              return InkWell(
                onTap: isOpen
                    ? () => setState(() {
                          if (type == PollType.singleChoice) {
                            _selected
                              ..clear()
                              ..add(o.id);
                          } else {
                            _selected.contains(o.id)
                                ? _selected.remove(o.id)
                                : _selected.add(o.id);
                          }
                        })
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                              isOpen
                                  ? (type == PollType.singleChoice
                                      ? (selected
                                          ? Icons.radio_button_checked_rounded
                                          : Icons
                                              .radio_button_unchecked_rounded)
                                      : (selected
                                          ? Icons.check_box_rounded
                                          : Icons
                                              .check_box_outline_blank_rounded))
                                  : Icons.bar_chart_rounded,
                              size: 20,
                              color: accent),
                          const SizedBox(width: 10),
                          Expanded(child: Text(o.text)),
                          Text('$pct%', style: theme.textTheme.bodySmall),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Accent progress bar (V2 §11 — color propagation).
                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(DesignTokens.radiusFull),
                        child: SizedBox(
                          height: 4,
                          child: LinearProgressIndicator(
                            value: total == 0 ? 0 : o.voteCount / total,
                            minHeight: 4,
                            color: accent,
                            backgroundColor: accent.withValues(alpha: 0.18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            if (isOpen) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: DesignTokens.textPrimary),
                      onPressed: _selected.isEmpty ? null : _vote,
                      child: Text(l.vote),
                    ),
                  ),
                  if (canClose) ...[
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _close,
                      child: Text(l.closePoll),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// V2 §4 — "Closes in 2h 30m" / "Closed 1h ago" / "Closes at HH:mm".
  String _deadlineLabel(AppLocalizations l) {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final dl = _poll.deadlineAt!;
    final diff = dl - now;
    if (diff <= 0) {
      final abs = (-diff);
      final hours = (abs / 3600000).floor();
      if (hours >= 24) {
        return l.closedDaysAgo('${(hours / 24).round()}');
      }
      if (hours >= 1) {
        return l.closedHoursAgo('$hours');
      }
      return l.closedMinutesAgo('${(abs / 60000).round()}');
    }
    final hours = (diff / 3600000).floor();
    if (hours >= 24) {
      return l.closesInDays('${(hours / 24).round()}');
    }
    if (hours >= 1) {
      return l.closesInHours('$hours');
    }
    return l.closesInMinutes('${(diff / 60000).round()}');
  }
}

class _CreatePollSheet extends StatefulWidget {
  const _CreatePollSheet({required this.eventId});

  final String eventId;

  @override
  State<_CreatePollSheet> createState() => _CreatePollSheetState();
}

class _CreatePollSheetState extends State<_CreatePollSheet> {
  final _question = TextEditingController();
  final _options = <TextEditingController>[
    TextEditingController(),
    TextEditingController()
  ];
  PollType _type = PollType.singleChoice;

  // V2 §3 — visibility (anonymous / public) (FIX_PLAN S5-T3).
  PollVisibility _visibility = PollVisibility.public;

  // V2 §4 — deadline (nullable = no deadline) (FIX_PLAN S5-T3).
  DateTime? _deadline;

  @override
  void dispose() {
    _question.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOption() => setState(() => _options.add(TextEditingController()));

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null) return;
    setState(() {
      _deadline = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _save() async {
    if (_question.text.trim().isEmpty) return;
    final texts =
        _options.map((c) => c.text).where((t) => t.trim().isNotEmpty).toList();
    if (texts.length < 2) return;
    final deadlineAt =
        _deadline?.toUtc().millisecondsSinceEpoch;
    try {
      await serviceLocator<PollRepository>().create(
        eventId: widget.eventId,
        question: _question.text,
        optionTexts: texts,
        type: _type,
        visibility: _visibility,
        deadlineAt: deadlineAt,
      );
      if (mounted) Navigator.of(context).pop(true);
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
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.addPoll, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _question,
              decoration: InputDecoration(labelText: l.title),
            ),
            const SizedBox(height: 12),
            SegmentedButton<PollType>(
              segments: [
                ButtonSegment(
                    value: PollType.singleChoice, label: Text(l.singleChoice)),
                ButtonSegment(
                    value: PollType.multipleChoice,
                    label: Text(l.multipleChoice)),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 12),
            // V2 §3 — visibility selector (FIX_PLAN S5-T3).
            SegmentedButton<PollVisibility>(
              segments: [
                ButtonSegment(
                  value: PollVisibility.public,
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: Text(l.pollPublic),
                ),
                ButtonSegment(
                  value: PollVisibility.anonymous,
                  icon: const Icon(Icons.visibility_off_outlined, size: 18),
                  label: Text(l.pollAnonymous),
                ),
              ],
              selected: {_visibility},
              onSelectionChanged: (s) => setState(() => _visibility = s.first),
            ),
            const SizedBox(height: 12),
            // V2 §4 — deadline picker (FIX_PLAN S5-T3).
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDeadline,
                    icon: const Icon(Icons.schedule_rounded),
                    label: Text(
                      _deadline == null
                          ? l.pollDeadline
                          : '${_deadline!.day}/${_deadline!.month} ${_deadline!.hour.toString().padLeft(2, '0')}:${_deadline!.minute.toString().padLeft(2, '0')}',
                    ),
                  ),
                ),
                if (_deadline != null)
                  IconButton(
                    tooltip: l.cancel,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(() => _deadline = null),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ..._options.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: c,
                    decoration: InputDecoration(labelText: l.pollOption),
                  ),
                )),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addOption,
                icon: const Icon(Icons.add_rounded),
                label: Text(l.addOption),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(onPressed: _save, child: Text(l.save)),
          ],
        ),
      ),
    );
  }
}
