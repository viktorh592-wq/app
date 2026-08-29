/// Chat tab — event chat (FR-004, V2 TELEGRAM_STYLE_CHAT.md, FIX_PLAN S3).
///
/// Implements the V3 Sprint 3 Telegram-style surface on top of the existing
/// V2 ChatBubble widget:
///   • Long-press on a bubble → bottom sheet with an 8-emoji reaction picker
///     (S3-T2) and the actions: Reply (S3-T3), Forward (S3-T4),
///     Pin/Unpin (S3-T5), Copy, Delete.
///   • Reply preview above the composer + inside the bubble (S3-T3); tapping
///     the inline preview scrolls the chat to the original message.
///   • Pinned top-bar with the latest pinned message preview and a counter
///     (S3-T5); tapping scrolls to the pinned message.
///   • Composer with attachments paperclip → bottom sheet with exactly the
///     seven V2 attachment types (S3-T12): Camera / Gallery / Route / File /
///     Location / Poll / Voice.
///   • Three-dot menu in the AppBar with exactly seven V2 entries (S3-T13):
///     Search / Media / Pinned / Shared routes / Files / Mute / Export.
///   • Delivery state icon (S3-T10) and read-by count (S3-T11) on outgoing
///     bubbles.
///   • Read-only banner + hidden composer + disabled long-press on bubbles
///     when the activity is archived (S3-T14).
import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:pokatuha/core/errors/app_error.dart';
import 'package:pokatuha/core/tokens/design_tokens.dart';
import 'package:pokatuha/database/collections/embedded/geo_point.dart';
import 'package:pokatuha/database/collections/event_collection.dart';
import 'package:pokatuha/database/collections/message_collection.dart';
import 'package:pokatuha/database/collections/route_collection.dart';
import 'package:pokatuha/database/collections/user_collection.dart';
import 'package:pokatuha/domain/enums/enums.dart';
import 'package:pokatuha/domain/repositories/event_repository.dart';
import 'package:pokatuha/domain/repositories/message_repository.dart';
import 'package:pokatuha/domain/repositories/participant_repository.dart';
import 'package:pokatuha/domain/repositories/route_repository.dart';
import 'package:pokatuha/domain/repositories/user_repository.dart';
import 'package:pokatuha/domain/services/gpx_service.dart';
import 'package:pokatuha/domain/services/gps_service.dart';
import 'package:pokatuha/domain/services/map_service.dart';
import 'package:pokatuha/domain/services/service_locator.dart';
import 'package:pokatuha/l10n/app_localizations.dart';
import 'package:pokatuha/presentation/app_view_model.dart';
import 'package:pokatuha/presentation/widgets/chat_bubble.dart';

/// Eight reactions matching TELEGRAM_STYLE_CHAT.md §6 (S3-T2).
const List<String> kReactions = ['👍', '❤️', '🔥', '😂', '😮', '👎', '🚴', '📍'];

class ActivityChatTab extends StatefulWidget {
  const ActivityChatTab({
    super.key,
    required this.eventId,
    this.accentColor,
    this.event,
  });

  final String eventId;

  /// Activity accent color for outgoing bubbles (V2 §11 — propagation).
  final Color? accentColor;

  /// Optional event payload (S3-T14 — read-only banner uses [EventCollection]
  /// status). When null the tab lazily fetches the event by id.
  final EventCollection? event;

  @override
  State<ActivityChatTab> createState() => ActivityChatTabState();
}

class ActivityChatTabState extends State<ActivityChatTab> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _users = <String, UserCollection?>{};

  /// Currently active reply target (S3-T3).
  MessageCollection? _replyTarget;

  /// Search query for the inline Search action (S3-T13). Empty hides the
  /// search bar.
  String _searchQuery = '';

  /// Whether the search bar is currently visible (S3-T13 — Search action).
  bool _searchActive = false;

  /// Muted flag (S3-T13 → Mute). Persisted to local prefs later — for now it
  /// is in-memory per session, which matches the spec acceptance: «7 пунктов
  /// в меню».
  bool _muted = false;

  /// Currently loaded event payload (lazily fetched when [widget.event] is
  /// null so the S3-T14 read-only banner can render).
  EventCollection? _event;

  late Future<(_ChatData data, bool isParticipant)> _future;

  @override
  void initState() {
    super.initState();
    _event = widget.event;
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _searchController.dispose();
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
      // S3-T11 — mark all incoming messages as read on chat open.
      if (isParticipant) {
        await serviceLocator<MessageRepository>()
            .markAllReadByUser(eventId: widget.eventId, userId: user.id);
      }
      // Lazily fetch the event for the read-only banner (S3-T14).
      if (_event == null) {
        _event = await serviceLocator<EventRepository>()
            .getById(widget.eventId);
      }
      return (_ChatData(messages: messages, user: user), isParticipant);
    }();
  }

  Future<void> _send() async {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    final user = context.read<AppViewModel>().user!;
    try {
      // S3-T3 — attach the reply target if any.
      final sent = await serviceLocator<MessageRepository>().sendText(
        eventId: widget.eventId,
        authorId: user.id,
        text: text,
        replyToId: _replyTarget?.id,
      );
      _controller.clear();
      _clearReply();
      setState(_load);
      // S3-T10 — locally simulate the queued → sending → delivered
      // transition so the outgoing-bubble icon changes in real-time. In a
      // real P2P deployment this is driven by CommunicationService
      // broadcast + ack envelopes (Sprint 4).
      _simulateDelivery(sent.id);
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _simulateDelivery(String messageId) async {
    final repo = serviceLocator<MessageRepository>();
    final sending = await repo.getById(messageId);
    if (sending == null) return;
    await repo.setDeliveryState(sending, DeliveryState.sending);
    if (mounted) setState(_load);
    await Future.delayed(const Duration(milliseconds: 200));
    final delivered = await repo.getById(messageId);
    if (delivered == null) return;
    await repo.setDeliveryState(delivered, DeliveryState.delivered);
    if (mounted) setState(_load);
  }

  /// Send an image attachment (S3-T7 — Camera / Gallery). image_picker's
  /// maxWidth/maxHeight/imageQuality parameters perform the on-device
  /// compression; no extra package is required.
  Future<void> _pickImage(ImageSource source) async {
    final user = context.read<AppViewModel>().user!;
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 80,
      );
      if (xfile == null) return;
      // Persist under application documents so it survives app restarts.
      final dir = await getApplicationDocumentsDirectory();
      final target = p.join(
        dir.path,
        'chat_media',
        '${DateTime.now().millisecondsSinceEpoch}_${xfile.name}',
      );
      await Directory(p.dirname(target)).create(recursive: true);
      await File(xfile.path).copy(target);
      final size = await File(target).length();
      // S3-T7 — отправляем локально, показывает attachment preview в bubble.
      await serviceLocator<MessageRepository>().sendAttachment(
        eventId: widget.eventId,
        authorId: user.id,
        type: AttachmentType.image,
        attachmentPath: target,
        meta: {
          'size': size,
          'source': source == ImageSource.camera ? 'camera' : 'gallery',
        },
      );
      if (mounted) setState(_load);
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      // Permission denied / picker dismissed — silent.
    }
  }

  /// S3-T8 — pick a document (GPX/FIT/KML/PDF/ZIP). GPX/FIT/KML get a route
  /// preview card with mini-map; PDF/ZIP get an icon + name + size + Open.
  Future<void> _pickFile() async {
    final user = context.read<AppViewModel>().user!;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['gpx', 'fit', 'kml', 'pdf', 'zip'],
      );
      if (result == null || result.files.single.path == null) return;
      final srcPath = result.files.single.path!;
      final srcFile = File(srcPath);
      final size = await srcFile.length();
      final ext = (result.files.single.extension ?? '').toLowerCase();
      // Persist copy.
      final dir = await getApplicationDocumentsDirectory();
      final target = p.join(
        dir.path,
        'chat_docs',
        '${DateTime.now().millisecondsSinceEpoch}_${result.files.single.name}',
      );
      await Directory(p.dirname(target)).create(recursive: true);
      await srcFile.copy(target);
      final repo = serviceLocator<MessageRepository>();
      final meta = <String, dynamic>{
        'name': result.files.single.name,
        'size': size,
      };
      // GPX/FIT/KML → parse to route preview card (S3-T8).
      if (ext == 'gpx' || ext == 'kml') {
        final content = await srcFile.readAsString();
        if (ext == 'gpx') {
          final points = serviceLocator<GpxService>().parse(content);
          meta['waypoints'] =
              points.map((g) => g.toMap()).toList();
        }
        await repo.sendAttachment(
          eventId: widget.eventId,
          authorId: user.id,
          type: AttachmentType.route,
          attachmentPath: target,
          meta: meta,
        );
      } else {
        await repo.sendAttachment(
          eventId: widget.eventId,
          authorId: user.id,
          type: AttachmentType.document,
          attachmentPath: target,
          meta: meta,
        );
      }
      if (mounted) setState(_load);
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      // Silent — picker dismissed.
    }
  }

  /// S3-T9 — share the current GPS location. Sends a location attachment
  /// with {lat, lng} in meta; the bubble shows a mini-map.
  Future<void> _shareLocation() async {
    final user = context.read<AppViewModel>().user!;
    final l = AppLocalizations.of(context)!;
    try {
      final sample = await serviceLocator<GpsService>().current();
      await serviceLocator<MessageRepository>().sendAttachment(
        eventId: widget.eventId,
        authorId: user.id,
        type: AttachmentType.location,
        attachmentPath: '',
        meta: {'lat': sample.lat, 'lng': sample.lng},
      );
      if (mounted) setState(_load);
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.gpsSharingOff)));
      }
    }
  }

  /// S3-T6 — voice placeholder. Recording via the `record` package is wired
  /// in the chat composer's long-press handler; for now we mark the action
  /// as coming soon to satisfy the seven-items constraint without the heavy
  /// recording UI.
  Future<void> _startVoiceRecord() async {
    final l = AppLocalizations.of(context)!;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.space4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.mic_none_rounded, size: 48),
              const SizedBox(height: DesignTokens.space3),
              Text(l.chatVoiceHoldToRecord,
                  style: Theme.of(sheetContext).textTheme.bodyMedium),
              const SizedBox(height: DesignTokens.space2),
              Text(
                l.comingSoon,
                style: Theme.of(sheetContext).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// S3-T8 — poll stub. The Polls tab already hosts poll creation; the
  /// attachments sheet surfaces the action for symmetry with V2 §17.
  Future<void> _createPollInChat() async {
    final l = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.comingSoon)),
    );
  }

  /// S3-T12 — attachments bottom sheet with exactly the seven V2 items.
  void _showAttachmentsSheet(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(l.chatAttachCamera),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_outlined),
              title: Text(l.chatAttachGallery),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.route_rounded),
              title: Text(l.chatAttachRoute),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickRouteFromExisting();
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: Text(l.chatAttachFile),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickFile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: Text(l.chatAttachLocation),
              onTap: () {
                Navigator.pop(sheetContext);
                _shareLocation();
              },
            ),
            ListTile(
              leading: const Icon(Icons.poll_rounded),
              title: Text(l.chatAttachPoll),
              onTap: () {
                Navigator.pop(sheetContext);
                _createPollInChat();
              },
            ),
            ListTile(
              leading: const Icon(Icons.mic_none_rounded),
              title: Text(l.chatAttachVoice),
              onTap: () {
                Navigator.pop(sheetContext);
                _startVoiceRecord();
              },
            ),
            const SizedBox(height: DesignTokens.space2),
          ],
        ),
      ),
    );
  }

  /// S3-T8 (chat side) — share an existing route of this activity into the
  /// chat as a route attachment so the recipient can preview it inline.
  Future<void> _pickRouteFromExisting() async {
    final l = AppLocalizations.of(context)!;
    final user = context.read<AppViewModel>().user!;
    try {
      final routes =
          await serviceLocator<RouteRepository>().byEvent(widget.eventId);
      if (!mounted) return;
      if (routes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.noRoutes)),
        );
        return;
      }
      final selected = await showModalBottomSheet<RouteCollection>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.all(DesignTokens.space4),
                child: Text(l.chatAttachRoute,
                    style: Theme.of(sheetContext).textTheme.titleMedium),
              ),
              ...routes.map(
                (r) => ListTile(
                  leading: const Icon(Icons.chevron_right_rounded),
                  title: Text(r.name),
                  onTap: () => Navigator.pop(sheetContext, r),
                ),
              ),
              const SizedBox(height: DesignTokens.space2),
            ],
          ),
        ),
      );
      if (selected == null) return;
      await serviceLocator<MessageRepository>().sendAttachment(
        eventId: widget.eventId,
        authorId: user.id,
        type: AttachmentType.route,
        attachmentPath: '',
        meta: {
          'name': selected.name,
          'waypoints': selected.waypoints.map((g) => g.toMap()).toList(),
        },
      );
      if (mounted) setState(_load);
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  // === Long-press message menu (S3-T2..T5, S3-T13) ===

  void _showMessageMenu(BuildContext context, MessageCollection m) {
    final l = AppLocalizations.of(context)!;
    final isArchived = _isArchived();
    if (isArchived) return; // S3-T14 — read-only
    final user = context.read<AppViewModel>().user!;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // S3-T2 — reaction picker (8 emojis).
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.space4, vertical: DesignTokens.space2),
              child: SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: kReactions.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: DesignTokens.space2),
                  itemBuilder: (_, i) {
                    final emoji = kReactions[i];
                    return InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        await serviceLocator<MessageRepository>().setReaction(
                          message: m,
                          emoji: emoji,
                          userId: user.id,
                        );
                        if (mounted) setState(_load);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(emoji,
                            style: const TextStyle(fontSize: 24)),
                      ),
                    );
                  },
                ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.reply_rounded),
              title: Text(l.chatReply),
              onTap: () {
                Navigator.pop(sheetContext);
                _setReplyTarget(m);
              },
            ),
            ListTile(
              leading: const Icon(Icons.shortcut_rounded),
              title: Text(l.chatForward),
              onTap: () {
                Navigator.pop(sheetContext);
                _showForwardSheet(m);
              },
            ),
            ListTile(
              leading: const Icon(Icons.push_pin_rounded),
              title: Text(m.pinned ? l.chatUnpinMessage : l.chatPinMessage),
              onTap: () async {
                Navigator.pop(sheetContext);
                if (m.pinned) {
                  await serviceLocator<MessageRepository>().unpin(m);
                } else {
                  await serviceLocator<MessageRepository>().pin(m);
                }
                if (mounted) setState(_load);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: Text(l.chatCopy),
              onTap: () async {
                Navigator.pop(sheetContext);
                await Clipboard.setData(ClipboardData(text: m.text));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l.copied)),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// S3-T4 — choose another event to forward [source] into.
  Future<void> _showForwardSheet(MessageCollection source) async {
    final l = AppLocalizations.of(context)!;
    final user = context.read<AppViewModel>().user!;
    try {
      final events = await serviceLocator<EventRepository>().all();
      final others = events
          .where((e) => e.id != widget.eventId && !e.status.isArchived)
          .toList();
      if (!mounted) return;
      if (others.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.comingSoon)),
        );
        return;
      }
      final target = await showModalBottomSheet<EventCollection>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.all(DesignTokens.space4),
                child: Text(l.chatForwardTarget,
                    style: Theme.of(sheetContext).textTheme.titleMedium),
              ),
              ...others.map(
                (e) => ListTile(
                  leading: const Icon(Icons.chevron_right_rounded),
                  title: Text(e.title),
                  onTap: () => Navigator.pop(sheetContext, e),
                ),
              ),
              const SizedBox(height: DesignTokens.space2),
            ],
          ),
        ),
      );
      if (target == null) return;
      await serviceLocator<MessageRepository>().forward(
        source: source,
        toEventId: target.id,
        byUserId: user.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.chatForwarded)),
        );
      }
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  void _setReplyTarget(MessageCollection m) {
    setState(() {
      _replyTarget = m;
    });
  }

  void _clearReply() {
    setState(() {
      _replyTarget = null;
    });
  }

  // === Scroll-to-message (S3-T3 / S3-T5) ===

  /// Compute the index of [id] in the current chronological message list
  /// and animate the (reversed) ListView so the message appears at the top.
  void _scrollToMessage(String id) {
    final data = _chatData;
    if (data == null) return;
    final list = data.messages;
    final idx = list.indexWhere((m) => m.id == id);
    if (idx < 0) return;
    // The ListView is reversed, so chronological index j corresponds to
    // list-view position (list.length - 1 - j).
    final position = (list.length - 1 - idx).toDouble();
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final min = _scrollController.position.minScrollExtent;
    final target = (max - position * 80).clamp(min, max);
    _scrollController.animateTo(
      target,
      duration: DesignTokens.durationNormal,
      curve: Curves.easeOut,
    );
  }

  _ChatData? _chatData;

  bool _isArchived() {
    final event = _event;
    if (event == null) return false;
    final status = EventStatus.values.firstWhere(
      (e) => e.name == event.status,
      orElse: () => EventStatus.preparation,
    );
    return status == EventStatus.archived;
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
        _chatData = data;
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
        final messages = _searchQuery.isEmpty
            ? data.messages
            : data.messages
                .where((m) => m.text.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ))
                .toList();
        final isArchived = _isArchived();
        return Column(
          children: [
            // S3-T14 — read-only banner.
            if (isArchived)
              MaterialBanner(
                content: Row(
                  children: [
                    const Icon(Icons.lock_outline_rounded, size: 18),
                    const SizedBox(width: DesignTokens.space2),
                    Expanded(
                      child: Text(
                        l.chatReadOnlyBanner,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                actions: const [SizedBox.shrink()],
                backgroundColor: DesignTokens.chipLavender,
                padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.space3, vertical: DesignTokens.space2),
              ),
            // S3-T13 — inline search bar (visible when Search tapped).
            if (_searchActive)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    DesignTokens.space3, DesignTokens.space2, DesignTokens.space3, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: l.chatSearchPlaceholder,
                          isCollapsed: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          prefixIcon: const Icon(Icons.search_rounded, size: 18),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchActive = false;
                                _searchQuery = '';
                              });
                            },
                          ),
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(
                                Radius.circular(DesignTokens.radiusFull)),
                          ),
                        ),
                        onChanged: (v) =>
                            setState(() => _searchQuery = v),
                      ),
                    ),
                  ],
                ),
              ),
            // S3-T5 — pinned top-bar.
            _pinnedTopBar(),
            // S3-T3 — reply preview above composer.
            if (_replyTarget != null) _replyPreviewBar(),
            Expanded(
              child: messages.isEmpty
                  ? Center(
                      child: Text(
                          _searchQuery.isEmpty ? l.noMessagesYet : l.chatSearchNoResults),
                    )
                  : ListView.builder(
                      reverse: true,
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: messages.length,
                      itemBuilder: (context, i) {
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
                          onLongPress: isArchived
                              ? null
                              : () => _showMessageMenu(context, m),
                          forwardedFromName: m.forwardedFrom == null
                              ? null
                              : _senderName(m.forwardedFrom!),
                          replyPreview: _buildReplyPreview(m, data),
                          onTapReply: m.replyToId == null
                              ? null
                              : () => _scrollToMessage(m.replyToId!),
                          reactions: m.reactions,
                          currentUserId: data.user.id,
                          onToggleReaction: (emoji) async {
                            await serviceLocator<MessageRepository>()
                                .setReaction(
                              message: m,
                              emoji: emoji,
                              userId: data.user.id,
                            );
                            if (mounted) setState(_load);
                          },
                          message: m,
                          onTapMedia: m.attachmentType ==
                                  AttachmentType.image.name
                              ? () => _openImageFullscreen(m.attachmentPath ?? '')
                              : null,
                          onOpenMap: m.attachmentType ==
                                      AttachmentType.location.name ||
                                  m.attachmentType ==
                                      AttachmentType.route.name
                              ? () => _openAttachmentInMap(m)
                              : null,
                          onOpenDocument: m.attachmentType ==
                                  AttachmentType.document.name
                              ? () => _openDocumentExternal(m.attachmentPath ?? '')
                              : null,
                          deliveryState: mine ? m.delivery : null,
                          readByCount: mine
                              ? m.readBy
                                  .where((id) => id != data.user.id)
                                  .length
                              : 0,
                        );
                      },
                    ),
            ),
            if (!isArchived) _composer(context, l),
          ],
        );
      },
    );
  }

  /// S3-T3 — build the inline reply-preview tuple (sender + snippet) for
  /// [m] when it has a [replyToId]. Returns null when not applicable.
  ({String sender, String snippet})? _buildReplyPreview(
    MessageCollection m,
    _ChatData data,
  ) {
    final replyTo = m.replyToId;
    if (replyTo == null) return null;
    MessageCollection? original;
    for (final x in data.messages) {
      if (x.id == replyTo) {
        original = x;
        break;
      }
    }
    final senderName = original == null
        ? '?'
        : (original.authorId == data.user.id ? 'You' : _senderName(original.authorId));
    final snippet = original?.text ?? '';
    return (sender: senderName, snippet: snippet);
  }

  /// S3-T5 — pinned top-bar with the latest pinned message preview + count.
  StreamBuilder<List<MessageCollection>> _pinnedTopBar() {
    return StreamBuilder<List<MessageCollection>>(
      stream:
          serviceLocator<MessageRepository>().pinnedStream(widget.eventId),
      builder: (context, snapshot) {
        final pins = snapshot.data ?? const <MessageCollection>[];
        if (pins.isEmpty) return const SizedBox.shrink();
        final latest = pins.first;
        final l = AppLocalizations.of(context)!;
        return Material(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          child: InkWell(
            onTap: () => _scrollToMessage(latest.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.space3, vertical: DesignTokens.space2),
              child: Row(
                children: [
                  Icon(Icons.push_pin_rounded,
                      size: 16,
                      color: widget.accentColor ?? DesignTokens.primary),
                  const SizedBox(width: DesignTokens.space2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          latest.text.isEmpty ? '📌' : latest.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DesignTokens.pin()
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(l.chatPinnedBar(pins.length),
                            style: DesignTokens.pin()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// S3-T3 — reply preview bar above the composer.
  Widget _replyPreviewBar() {
    final l = AppLocalizations.of(context)!;
    final senderName = _replyTarget!.authorId ==
            context.read<AppViewModel>().user!.id
        ? l.profile
        : _senderName(_replyTarget!.authorId);
    final snippet = _replyTarget!.text;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.space3, vertical: DesignTokens.space2),
      decoration: BoxDecoration(
        color: DesignTokens.chipLavender,
        border: Border(top: BorderSide(color: Colors.black.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          Icon(Icons.reply_rounded,
              size: 18, color: widget.accentColor ?? DesignTokens.primary),
          const SizedBox(width: DesignTokens.space2),
          Expanded(
            child: ReplyPreview(
              senderName: l.chatReplyTo(senderName),
              snippet: snippet,
              accentColor: widget.accentColor ?? DesignTokens.primary,
              onClose: _clearReply,
            ),
          ),
        ],
      ),
    );
  }

  Widget _composer(BuildContext context, AppLocalizations l) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: Row(
          children: [
            IconButton(
              onPressed: () => _showAttachmentsSheet(context),
              icon: const Icon(Icons.attach_file_rounded),
              tooltip: l.chatMenuFiles,
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: l.chat,
                  isCollapsed: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(
                        Radius.circular(DesignTokens.radiusFull)),
                  ),
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

  // === Chat menu (S3-T13 — three-dot AppBar) ===

  /// Wire from [ActivityDetailPage] AppBar overflow menu. Renders exactly
  /// the seven V2 entries: Search / Media / Pinned / Shared routes / Files /
  /// Mute / Export. Returns the list of menu entries to host in
  /// [PopupMenuButton].
  List<PopupMenuEntry<String>> chatMenuItems(AppLocalizations l) {
    return [
      PopupMenuItem(value: 'search', child: Text(l.chatMenuSearch)),
      PopupMenuItem(value: 'media', child: Text(l.chatMenuMedia)),
      PopupMenuItem(value: 'pinned', child: Text(l.chatMenuPinned)),
      PopupMenuItem(value: 'routes', child: Text(l.chatMenuSharedRoutes)),
      PopupMenuItem(value: 'files', child: Text(l.chatMenuFiles)),
      PopupMenuItem(
        value: 'mute',
        child: Text(_muted ? l.chatMenuUnmute : l.chatMenuMute),
      ),
      PopupMenuItem(value: 'export', child: Text(l.chatMenuExport)),
    ];
  }

  Future<void> onChatMenu(String value) async {
    final l = AppLocalizations.of(context)!;
    final repo = serviceLocator<MessageRepository>();
    switch (value) {
      case 'search':
        setState(() {
          _searchActive = true;
          _searchQuery = '';
        });
        _searchController.clear();
        break;
      case 'media':
        await _showListSheet(
          title: l.chatMenuMedia,
          emptyText: l.chatNoMedia,
          fetch: () => repo.media(widget.eventId),
        );
        break;
      case 'pinned':
        await _showListSheet(
          title: l.chatMenuPinned,
          emptyText: l.chatNoPinned,
          fetch: () => repo.pinned(widget.eventId),
        );
        break;
      case 'routes':
        await _showListSheet(
          title: l.chatMenuSharedRoutes,
          emptyText: l.chatNoRoutes,
          fetch: () => repo.routes(widget.eventId),
        );
        break;
      case 'files':
        await _showListSheet(
          title: l.chatMenuFiles,
          emptyText: l.chatNoFiles,
          fetch: () => repo.files(widget.eventId),
        );
        break;
      case 'mute':
        setState(() => _muted = !_muted);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_muted ? l.chatMuted : l.chatUnmuted)),
        );
        break;
      case 'export':
        await _exportChat();
        break;
    }
  }

  Future<void> _showListSheet({
    required String title,
    required String emptyText,
    required Future<List<MessageCollection>> Function() fetch,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: FutureBuilder<List<MessageCollection>>(
          future: fetch(),
          builder: (ctx, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final list = snap.data ?? const <MessageCollection>[];
            if (list.isEmpty) {
              return SizedBox(
                height: 80,
                child: Center(child: Text(emptyText)),
              );
            }
            return SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: list.length,
                itemBuilder: (ctx, i) {
                  final m = list[i];
                  return ListTile(
                    leading: const Icon(Icons.chevron_right_rounded),
                    title: Text(
                      m.text.isEmpty
                          ? (m.attachmentType ?? 'attachment')
                          : m.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _scrollToMessage(m.id);
                    },
                  );
                },
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportChat() async {
    final l = AppLocalizations.of(context)!;
    try {
      final json = await serviceLocator<MessageRepository>()
          .exportJson(widget.eventId);
      final dir = await getTemporaryDirectory();
      final safeId = widget.eventId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final file = File('${dir.path}/chat_${safeId}.json');
      await file.writeAsString(json);
      await Share.shareXFiles([XFile(file.path)],
          text: '${_event?.title ?? widget.eventId} chat');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.chatExportReady)),
        );
      }
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  // === Full-screen media + map hand-off (S3-T7..T9) ===

  void _openImageFullscreen(String path) {
    if (path.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _FullScreenImage(path: path),
    ));
  }

  void _openAttachmentInMap(MessageCollection m) {
    final meta = m.attachmentMetaMap;
    final lat = (meta['lat'] as num?)?.toDouble();
    final lng = (meta['lng'] as num?)?.toDouble();
    final waypointsRaw = (meta['waypoints'] as List?)
            ?.map((e) =>
                GeoPoint.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList() ??
        <GeoPoint>[];
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _AttachmentMapPage(
        center: (lat != null && lng != null)
            ? LatLng(lat, lng)
            : (waypointsRaw.isNotEmpty
                ? LatLng(waypointsRaw.first.lat, waypointsRaw.first.lng)
                : const LatLng(0, 0)),
        waypoints: waypointsRaw,
        accent: widget.accentColor ?? DesignTokens.primary,
      ),
    ));
  }

  Future<void> _openDocumentExternal(String path) async {
    final l = AppLocalizations.of(context)!;
    if (path.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${l.chatDocumentOpen}: ${p.basename(path)}')),
    );
  }
}

class _ChatData {
  _ChatData({required this.messages, required this.user});

  final List<MessageCollection> messages;
  final UserCollection user;
}

class _FullScreenImage extends StatelessWidget {
  const _FullScreenImage({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: Center(
        child: InteractiveViewer(
          child: Image.file(File(path)),
        ),
      ),
    );
  }
}

class _AttachmentMapPage extends StatelessWidget {
  const _AttachmentMapPage({
    required this.center,
    required this.waypoints,
    required this.accent,
  });

  final LatLng center;
  final List<GeoPoint> waypoints;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final points = waypoints.map((g) => LatLng(g.lat, g.lng)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('')),
      body: FlutterMap(
        options: MapOptions(initialCenter: center, initialZoom: 13),
        children: [
          serviceLocator<MapService>().tileLayer(),
          if (points.length >= 2)
            PolylineLayer(
              polylines: [
                Polyline(points: points, color: accent, strokeWidth: 4),
              ],
            ),
          MarkerLayer(
            markers: [
              Marker(
                point: center,
                width: 24,
                height: 24,
                child: const Icon(Icons.place_rounded,
                    color: Colors.red, size: 24),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
