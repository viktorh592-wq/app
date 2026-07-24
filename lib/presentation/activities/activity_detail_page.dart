/// Activity detail — hub for an activity (FR-001..FR-009). Tabs: details,
/// chat, polls, route, participants. Actions: join / leave / start / finish
/// (UC-001..UC-004). Enforces business rules via EventService.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:pokatuha/core/errors/app_error.dart';
import 'package:pokatuha/database/collections/event_collection.dart';
import 'package:pokatuha/domain/enums/enums.dart';
import 'package:pokatuha/domain/repositories/event_repository.dart';
import 'package:pokatuha/domain/services/event_service.dart';
import 'package:pokatuha/domain/services/service_locator.dart';
import 'package:pokatuha/l10n/app_localizations.dart';
import 'package:pokatuha/presentation/app_view_model.dart';
import 'package:pokatuha/presentation/activities/tabs/activity_chat_tab.dart';
import 'package:pokatuha/presentation/activities/tabs/activity_details_tab.dart';
import 'package:pokatuha/presentation/activities/tabs/activity_participants_tab.dart';
import 'package:pokatuha/presentation/activities/tabs/activity_polls_tab.dart';
import 'package:pokatuha/presentation/activities/tabs/activity_route_tab.dart';
import 'package:pokatuha/presentation/widgets/status_chip.dart';

class ActivityDetailPage extends StatefulWidget {
  const ActivityDetailPage({super.key, required this.eventId});

  final String eventId;

  @override
  State<ActivityDetailPage> createState() => _ActivityDetailPageState();
}

class _ActivityDetailPageState extends State<ActivityDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  EventCollection? _event;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
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
    if (mounted) {
      setState(() {
        _event = event;
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
        body: const Center(child: Text('Activity not found')),
      );
    }
    final status = EventStatus.values.firstWhere(
      (e) => e.name == event.status,
      orElse: () => EventStatus.preparation,
    );
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            pinned: true,
            title:
                Text(event.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: [
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
                Tab(text: l.tabHome),
                Tab(text: l.chat),
                Tab(text: l.polls),
                Tab(text: l.route),
                Tab(text: l.participants),
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
            ActivityChatTab(eventId: event.id),
            ActivityPollsTab(eventId: event.id),
            ActivityRouteTab(eventId: event.id),
            ActivityParticipantsTab(eventId: event.id),
          ],
        ),
      ),
    );
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
