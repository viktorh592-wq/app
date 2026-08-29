/// Group → Activities tab (V2 GROUPS_AND_ACTIVITIES.md §1, §7): activities
/// of this group only (EventRepository.byGroup), searchable by title through
/// the V2 SearchBarV2. Each card shows a mini route map when a route exists
/// (V2 §8, FIX_PLAN S2-T5) and opens the six-action activity menu
/// (V2 §9 — Edit / Duplicate / Share / Pin / Archive / Delete, S2-T8).
/// Pinned activities are listed first (V2 §9).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:pokatuha/core/errors/app_error.dart';
import 'package:pokatuha/core/tokens/design_tokens.dart';
import 'package:pokatuha/database/collections/event_collection.dart';
import 'package:pokatuha/database/collections/group_collection.dart';
import 'package:pokatuha/database/collections/route_collection.dart';
import 'package:pokatuha/domain/repositories/activity_type_repository.dart';
import 'package:pokatuha/domain/repositories/event_repository.dart';
import 'package:pokatuha/domain/repositories/participant_repository.dart';
import 'package:pokatuha/domain/repositories/route_repository.dart';
import 'package:pokatuha/domain/services/event_service.dart';
import 'package:pokatuha/domain/services/service_locator.dart';
import 'package:pokatuha/l10n/app_localizations.dart';
import 'package:pokatuha/presentation/activities/activity_detail_page.dart';
import 'package:pokatuha/presentation/activities/create_activity_page.dart';
import 'package:pokatuha/presentation/app_view_model.dart';
import 'package:pokatuha/presentation/widgets/activity_card.dart';
import 'package:pokatuha/presentation/widgets/activity_menu_sheet.dart';
import 'package:pokatuha/presentation/widgets/empty_state.dart';
import 'package:pokatuha/presentation/widgets/mini_map_preview.dart';
import 'package:pokatuha/presentation/widgets/search_bar_v2.dart';

class GroupActivitiesTab extends StatefulWidget {
  const GroupActivitiesTab({super.key, required this.group});

  final GroupCollection group;

  @override
  State<GroupActivitiesTab> createState() => _GroupActivitiesTabState();
}

class _GroupActivitiesTabState extends State<GroupActivitiesTab>
    with AutomaticKeepAliveClientMixin {
  late Future<_GroupActivitiesData> _future;
  String _query = '';
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _load() {
    _future = () async {
      final events =
          await serviceLocator<EventRepository>().byGroup(widget.group.id);
      // Pinned activities first (V2 §9).
      events.sort((a, b) {
        if (a.pinnedInGroup != b.pinnedInGroup) {
          return a.pinnedInGroup ? -1 : 1;
        }
        return b.startAt.compareTo(a.startAt);
      });
      final types = await serviceLocator<ActivityTypeRepository>().all();
      final typeMap = {for (final t in types) t.id: t.label};
      final participants = serviceLocator<ParticipantRepository>();
      final routes = serviceLocator<RouteRepository>();
      final counts = <String, int>{};
      final firstRoutes = <String, RouteCollection>{};
      for (final e in events) {
        counts[e.id] = await participants.acceptedCount(e.id);
        final eventRoutes = await routes.byEvent(e.id);
        if (eventRoutes.isNotEmpty) firstRoutes[e.id] = eventRoutes.first;
      }
      return _GroupActivitiesData(
        events: events,
        typeLabels: typeMap,
        counts: counts,
        firstRoutes: firstRoutes,
      );
    }();
  }

  List<EventCollection> _filtered(_GroupActivitiesData data) {
    if (_query.isEmpty) return data.events;
    final q = _query.toLowerCase();
    return data.events
        .where((e) =>
            e.title.toLowerCase().contains(q) ||
            (data.typeLabels[e.activityTypeId] ?? '').toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l = AppLocalizations.of(context)!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: DesignTokens.space2),
          child: SearchBarV2(
            controller: _searchController,
            hintText: l.search,
            onChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(
                const Duration(milliseconds: 300),
                () => setState(() {}),
              );
              _query = v;
            },
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => setState(_load),
            child: FutureBuilder<_GroupActivitiesData>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = snapshot.data!;
                final list = _filtered(data);
                if (list.isEmpty) {
                  return ListView(
                    children: [
                      const SizedBox(height: 64),
                      EmptyState(
                        icon: Icons.event_outlined,
                        title: l.noActivities,
                        subtitle: l.noActivitiesHint,
                      ),
                    ],
                  );
                }
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final e = list[i];
                    final route = data.firstRoutes[e.id];
                    return ActivityCard(
                      event: e,
                      activityLabel:
                          data.typeLabels[e.activityTypeId] ?? e.activityTypeId,
                      participantCount: data.counts[e.id] ?? 0,
                      onTap: () => _open(context, e.id),
                      onMenuTap: () => _showMenu(context, e),
                      mapPreview: route != null
                          ? MiniMapPreview(
                              route: route,
                              meetingPoint: e.meetingPoint,
                              routeColor: Color(
                                e.accentColor ??
                                    EventCollection.defaultAccentColorArgb,
                              ),
                            )
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  void _open(BuildContext context, String id) {
    Navigator.of(context)
        .push(
            MaterialPageRoute(builder: (_) => ActivityDetailPage(eventId: id)))
        .then((_) => setState(_load));
  }

  // --- V2 §9 activity menu (FIX_PLAN S2-T8) ---

  void _showMenu(BuildContext context, EventCollection event) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => ActivityMenuSheet(
        event: event,
        onEdit: () => _edit(event),
        onDuplicate: () => _duplicate(event),
        onShare: () => _share(event),
        onPin: () => _togglePin(event),
        onArchive: () => _archive(event),
        onDelete: () => _delete(event),
      ),
    );
  }

  Future<void> _edit(EventCollection event) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CreateActivityPage(
        groupId: event.groupId ?? widget.group.id,
        event: event,
      ),
    ));
    if (mounted) setState(_load);
  }

  Future<void> _duplicate(EventCollection event) async {
    final l = AppLocalizations.of(context)!;
    final user = context.read<AppViewModel>().user;
    if (user == null) return;
    try {
      await serviceLocator<EventService>()
          .duplicate(event: event, organizer: user);
      if (mounted) {
        setState(_load);
        _toast(l.duplicated);
      }
    } on AppError catch (e) {
      _toast(e.message);
    }
  }

  void _share(EventCollection event) {
    // V2 §9 — share the activity deep link.
    Share.share('pokatuha://a/${event.id}', subject: event.title);
  }

  Future<void> _togglePin(EventCollection event) async {
    final l = AppLocalizations.of(context)!;
    try {
      await serviceLocator<EventService>()
          .setPinned(event, !event.pinnedInGroup);
      if (mounted) {
        setState(_load);
        _toast(event.pinnedInGroup ? l.unpinned : l.pinned);
      }
    } on AppError catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _archive(EventCollection event) async {
    final l = AppLocalizations.of(context)!;
    try {
      await serviceLocator<EventService>().archiveNow(event);
      if (mounted) {
        setState(_load);
        _toast(l.archived);
      }
    } on AppError catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _delete(EventCollection event) async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.delete),
        content: Text(l.deleteActivityConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await serviceLocator<EventService>().deleteActivity(event);
      if (mounted) {
        setState(_load);
        _toast(l.delete);
      }
    } on AppError catch (e) {
      _toast(e.message);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _GroupActivitiesData {
  _GroupActivitiesData({
    required this.events,
    required this.typeLabels,
    required this.counts,
    required this.firstRoutes,
  });

  final List<EventCollection> events;
  final Map<String, String> typeLabels;
  final Map<String, int> counts;
  final Map<String, RouteCollection> firstRoutes;
}
