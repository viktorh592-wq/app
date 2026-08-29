/// Group → Activities tab (V2 GROUPS_AND_ACTIVITIES.md §1, §7): activities
/// of this group only (EventRepository.byGroup), searchable by title.
import 'dart:async';

import 'package:flutter/material.dart';

import 'package:pokatuha/database/collections/event_collection.dart';
import 'package:pokatuha/database/collections/group_collection.dart';
import 'package:pokatuha/domain/repositories/activity_type_repository.dart';
import 'package:pokatuha/domain/repositories/event_repository.dart';
import 'package:pokatuha/domain/repositories/participant_repository.dart';
import 'package:pokatuha/domain/services/service_locator.dart';
import 'package:pokatuha/l10n/app_localizations.dart';
import 'package:pokatuha/presentation/activities/activity_detail_page.dart';
import 'package:pokatuha/presentation/widgets/activity_card.dart';
import 'package:pokatuha/presentation/widgets/empty_state.dart';

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
      final types = await serviceLocator<ActivityTypeRepository>().all();
      final typeMap = {for (final t in types) t.id: t.label};
      final participants = serviceLocator<ParticipantRepository>();
      final counts = <String, int>{};
      for (final e in events) {
        counts[e.id] = await participants.acceptedCount(e.id);
      }
      return _GroupActivitiesData(
          events: events, typeLabels: typeMap, counts: counts);
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: l.search,
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
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
                    return ActivityCard(
                      event: e,
                      activityLabel:
                          data.typeLabels[e.activityTypeId] ?? e.activityTypeId,
                      participantCount: data.counts[e.id] ?? 0,
                      onTap: () => _open(context, e.id),
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
}

class _GroupActivitiesData {
  _GroupActivitiesData({
    required this.events,
    required this.typeLabels,
    required this.counts,
  });

  final List<EventCollection> events;
  final Map<String, String> typeLabels;
  final Map<String, int> counts;
}
