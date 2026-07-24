/// Chat tab — event chat (FR-004). Text, images, replies, reactions, pinned
/// messages. Only participants may access (BR-003).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:pokatuha/core/errors/app_error.dart';
import 'package:pokatuha/core/utils/timestamps.dart';
import 'package:pokatuha/database/collections/message_collection.dart';
import 'package:pokatuha/database/collections/user_collection.dart';
import 'package:pokatuha/domain/repositories/message_repository.dart';
import 'package:pokatuha/domain/repositories/participant_repository.dart';
import 'package:pokatuha/domain/services/service_locator.dart';
import 'package:pokatuha/l10n/app_localizations.dart';
import 'package:pokatuha/presentation/app_view_model.dart';

class ActivityChatTab extends StatefulWidget {
  const ActivityChatTab({super.key, required this.eventId});

  final String eventId;

  @override
  State<ActivityChatTab> createState() => _ActivityChatTabState();
}

class _ActivityChatTabState extends State<ActivityChatTab> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  late Future<(List<MessageCollection>, UserCollection, bool)> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _load() {
    _future = () async {
      final user = context.read<AppViewModel>().user!;
      final participant = await serviceLocator<ParticipantRepository>()
          .byEventAndUser(widget.eventId, user.id);
      final isParticipant =
          participant != null && participant.status != 'invited';
      final messages =
          await serviceLocator<MessageRepository>().byEvent(widget.eventId);
      return (messages, user, isParticipant);
    }();
  }

  Future<void> _send() async {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    final user = context.read<AppViewModel>().user!;
    try {
      await serviceLocator<MessageRepository>().sendText(
        eventId: widget.eventId,
        authorId: user.id,
        text: text,
      );
      _controller.clear();
      setState(_load);
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
    return FutureBuilder<(List<MessageCollection>, UserCollection, bool)>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final (messages, _, isParticipant) = snapshot.data!;
        if (!isParticipant) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Only participants may access the chat (BR-003)',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          );
        }
        return Column(
          children: [
            Expanded(
              child: messages.isEmpty
                  ? const Center(child: Text('No messages yet'))
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(12),
                      itemCount: messages.length,
                      itemBuilder: (context, i) {
                        final m = messages[messages.length - 1 - i];
                        return _bubble(context, m);
                      },
                    ),
            ),
            _composer(context, l),
          ],
        );
      },
    );
  }

  Widget _bubble(BuildContext context, MessageCollection m) {
    final theme = Theme.of(context);
    final user = context.read<AppViewModel>().user;
    final mine = m.authorId == user?.id;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: mine
              ? theme.colorScheme.primary.withValues(alpha: 0.16)
              : theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(m.text, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(
              Timestamps.relativeFromNow(m.createdAt, 'en'),
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _composer(BuildContext context, AppLocalizations l) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: l.chat,
                  isCollapsed: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _send,
              icon: const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
