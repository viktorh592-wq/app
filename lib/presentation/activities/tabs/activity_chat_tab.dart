/// Chat tab — event chat (FR-004). Text messages are rendered through the
/// V2 ChatBubble widget (Telegram-style, TELEGRAM_STYLE_CHAT.md §3–§5;
/// FIX_PLAN S2-T2): outgoing bubbles use the activity accent color (V2 §11),
/// consecutive messages from one sender within 5 minutes are visually
/// grouped (avatar only on the first, timestamp only on the last).
/// Only participants may access (BR-003). Reactions/replies arrive in
/// Sprint 3 (S3-T2/S3-T3); long-press shows message details meanwhile.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:pokatuha/core/errors/app_error.dart';
import 'package:pokatuha/core/tokens/design_tokens.dart';
import 'package:pokatuha/database/collections/message_collection.dart';
import 'package:pokatuha/database/collections/user_collection.dart';
import 'package:pokatuha/domain/repositories/message_repository.dart';
import 'package:pokatuha/domain/repositories/participant_repository.dart';
import 'package:pokatuha/domain/repositories/user_repository.dart';
import 'package:pokatuha/domain/services/service_locator.dart';
import 'package:pokatuha/l10n/app_localizations.dart';
import 'package:pokatuha/presentation/app_view_model.dart';
import 'package:pokatuha/presentation/widgets/chat_bubble.dart';

class ActivityChatTab extends StatefulWidget {
  const ActivityChatTab({super.key, required this.eventId, this.accentColor});

  final String eventId;

  /// Activity accent color for outgoing bubbles (V2 §11 — propagation).
  final Color? accentColor;

  @override
  State<ActivityChatTab> createState() => _ActivityChatTabState();
}

class _ActivityChatTabState extends State<ActivityChatTab> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  late Future<(_ChatData data, bool isParticipant)> _future;
  final _users = <String, UserCollection?>{};

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
      // Resolve distinct authors once (local-first, small N).
      for (final m in messages) {
        if (!_users.containsKey(m.authorId)) {
          _users[m.authorId] =
              await serviceLocator<UserRepository>().getById(m.authorId);
        }
      }
      return (_ChatData(messages: messages, user: user), isParticipant);
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
    return FutureBuilder<(_ChatData, bool)>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final (data, isParticipant) = snapshot.data!;
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
        final messages = data.messages;
        return Column(
          children: [
            Expanded(
              child: messages.isEmpty
                  ? Center(child: Text(l.noMessagesYet))
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(12),
                      itemCount: messages.length,
                      itemBuilder: (context, i) {
                        // ListView is reversed: index i maps to the message
                        // at position j in chronological order.
                        final j = messages.length - 1 - i;
                        final m = messages[j];
                        final mine = m.authorId == data.user.id;
                        return ChatBubble(
                          text: m.text,
                          isOutgoing: mine,
                          senderName: mine ? null : _senderName(m.authorId),
                          timestamp:
                              DateTime.fromMillisecondsSinceEpoch(m.createdAt),
                          showAvatar: _startsGroup(messages, j),
                          showTimestamp: _endsGroup(messages, j),
                          outgoingColor: widget.accentColor,
                          onLongPress: () => _showMessageDetails(context, m),
                        );
                      },
                    ),
            ),
            _composer(context, l),
          ],
        );
      },
    );
  }

  /// Telegram-like grouping (§5): a new group starts when the previous
  /// message is from another author or older than 5 minutes.
  bool _startsGroup(List<MessageCollection> messages, int j) {
    if (j == 0) return true;
    final prev = messages[j - 1];
    final cur = messages[j];
    return prev.authorId != cur.authorId ||
        cur.createdAt - prev.createdAt > 5 * 60 * 1000;
  }

  /// The last bubble of a group shows the timestamp (§5).
  bool _endsGroup(List<MessageCollection> messages, int j) {
    if (j == messages.length - 1) return true;
    final next = messages[j + 1];
    final cur = messages[j];
    return next.authorId != cur.authorId ||
        next.createdAt - cur.createdAt > 5 * 60 * 1000;
  }

  String _senderName(String authorId) =>
      _users[authorId]?.displayName ?? 'User ${authorId.substring(0, 6)}';

  /// Placeholder message-details sheet until reactions / replies land in
  /// Sprint 3 (S3-T2, S3-T3).
  void _showMessageDetails(BuildContext context, MessageCollection m) {
    final l = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.space4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.details,
                  style: Theme.of(sheetContext).textTheme.titleMedium),
              const SizedBox(height: DesignTokens.space3),
              Text('${l.profile}: ${_senderName(m.authorId)}'),
              const SizedBox(height: DesignTokens.space2),
              Text(
                '${l.date}: ${DateTime.fromMillisecondsSinceEpoch(m.createdAt).toLocal()}',
              ),
            ],
          ),
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

class _ChatData {
  _ChatData({required this.messages, required this.user});

  final List<MessageCollection> messages;
  final UserCollection user;
}
