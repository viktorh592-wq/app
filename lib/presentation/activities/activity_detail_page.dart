/// Activity detail — hub for an activity (FR-001..FR-009). Exactly four tabs
/// (V2 ARCHITECTURE_V2.md §7, FIGMA_IMPLEMENTATION.md §6, FIX_PLAN S2-T10):
/// Main / Chat / Polls / Route. Participants live as a block inside the Main
/// tab. The header carries the activity type / date / meeting point summary
/// (V2 §13); actions: join / leave / start / finish (UC-001..UC-004) via
/// EventService. The activity accent color (V2 §11) propagates to chat
/// bubbles, polls and route polyline.
///
/// V3 Sprint 3 — the AppBar hosts a chat-only three-dot menu (S3-T13) when
/// the Chat tab is active, surfacing exactly the seven V2 entries: Search /
/// Media / Pinned / Shared routes / Files / Mute / Export.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pokatuha/core/errors/app_error.dart';
import 'package:pokatuha/core/utils/timestamps.dart';
import 'package:pokatuha/database/collections/event_collection.dart';
import 'package:pokatuha/domain/enums/enums.dart';
import 'package:pokatuha/domain/repositories/activity_type_repository.dart';
import 'package:pokatuha/domain/repositories/event_repository.dart';
import 'package:pokatuha/domain/services/event_service.dart';
import 'package:pokatuha/domain/services/service_locator.dart';
import 'package:pokatuha/l10n/app_localizations.dart';
import 'package:pokatuha/presentation/app_view_model.dart';
import 'package:pokatuha/presentation/activities/tabs/activity_chat_tab.dart';
import 'package:pokatuha/presentation/activities/tabs/activity_details_tab.dart';
import 'package:pokatuha/presentation/activities/tabs/activity_polls_tab.dart';
import 'package:pokatuha/presentation/activities/tabs/activity_route_tab.dart';
import 'package:pokatuha/presentation/widgets/status_chip.dart';

class ActivityDetailPage extends StatefulWidget {
  const ActivityDetailPage({
    super.key,
    required this.eventId,
    this.initialTabIndex = 0,
  });

  final String eventId;

  /// S6-T6 (S4-T10) — initially selected sub-tab. The Map tab passes
  /// `2` (Route) so tapping a meeting marker opens the activity directly
  /// on its route map (FIX_PLAN §S4-T10 step 1).
  final int initialTabIndex;

  @override
  State<ActivityDetailPage> createState() => _ActivityDetailPageState();
}

class _ActivityDetailPageState extends State<ActivityDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  EventCollection? _event;
  bool _loading = true;
  String _activityLabel = '';

  /// S3-T13 — chat tab key so the AppBar overflow menu can drive chat menu
  /// actions (Search / Media / Pinned / Shared routes / Files / Mute /
  /// Export).
  final GlobalKey<ActivityChatTabState> _chatKey =
      GlobalKey<ActivityChatTabState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      initialIndex: widget.initialTabIndex.clamp(0, 3),
      vsync: this,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final event =
        await serviceLocator<EventRepository>().getById(widget.eventId);
    String label = '';
    if (event != null) {
      final types = await serviceLocator<ActivityTypeRepository>().all();
      label =
          types.where((t) => t.id == event.activityTypeId).firstOrNull?.label ??
              event.activityTypeId;
    }
    if (mounted) {
      setState(() {
        _event = event;
        _activityLabel = label;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (_loading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final event = _event;
    if (event == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l.activityNotFound)),
      );
    }
    final status = EventStatus.values.firstWhere(
      (e) => e.name == event.status,
      orElse: () => EventStatus.preparation,
    );
    final accentColor = Color(
      event.accentColor ?? EventCollection.defaultAccentColorArgb,
    );
    // S3-T13 — chat menu only visible on the Chat tab.
    final onChatTab = _tabController.index == 1;
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            pinned: true,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                // V2 §13 — type / date / meeting point live in the header.
                Text(
                  _headerSubtitle(event, l),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            actions: [
              if (onChatTab)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: (value) =>
                      _chatKey.currentState?.onChatMenu(value),
                  itemBuilder: (_) =>
                      _chatKey.currentState?.chatMenuItems(l) ??
                      const <PopupMenuEntry<String>>[],
                ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(child: StatusChip(status: status)),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: l.tabMain),
                Tab(text: l.chat),
                Tab(text: l.polls),
                Tab(text: l.route),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            ActivityDetailsTab(
              event: event,
              onAction: _handleAction,
              onChanged: _load,
            ),
            ActivityChatTab(
              key: _chatKey,
              eventId: event.id,
              accentColor: accentColor,
              event: event,
            ),
            ActivityPollsTab(eventId: event.id, accentColor: accentColor),
            ActivityRouteTab(eventId: event.id, accentColor: accentColor),
          ],
        ),
      ),
    );
  }

  /// Header summary: activity type • date • meeting point (V2 §13).
  String _headerSubtitle(EventCollection event, AppLocalizations l) {
    // V3.0.3 fix — use the active locale for date formatting instead of
    // hardcoded 'en' (user-reported Issue 5: English text in Russian UI).
    final localeCode = Localizations.localeOf(context).languageCode;
    final parts = <String>[
      if (_activityLabel.isNotEmpty) _activityLabel,
      Timestamps.formatLocalDateTime(event.startAt, localeCode),
      if (event.meetingPointLabel != null &&
          event.meetingPointLabel!.isNotEmpty)
        event.meetingPointLabel!,
    ];
    return parts.join(' • ');
  }

  /// Dispatch join / leave / start / finish (UC-002..UC-004, BR-005).
  Future<void> _handleAction(EventAction action) async {
    final event = _event;
    if (event == null) return;
    final user = context.read<AppViewModel>().user!;
    try {
      switch (action) {
        case EventAction.join:
          await serviceLocator<EventService>().join(event: event, user: user);
          break;
        case EventAction.leave:
          await serviceLocator<EventService>().leave(event: event, user: user);
          break;
        case EventAction.startRide:
          await serviceLocator<EventService>().startRide(event);
          break;
        case EventAction.finishRide:
          await serviceLocator<EventService>().finishRide(event);
          break;
      }
      await _load();
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}

/// Actions surfaced by the details tab.
enum EventAction { join, leave, startRide, finishRide }
