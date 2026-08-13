/// Activities tab — full list of activities with search (FR-001).
import 'package:flutter/material.dart';
import 'package:pokatuha/database/collections/event_collection.dart';
import 'package:pokatuha/domain/repositories/activity_type_repository.dart';
import 'package:pokatuha/domain/repositories/event_repository.dart';
import 'package:pokatuha/domain/repositories/participant_repository.dart';
import 'package:pokatuha/domain/services/service_locator.dart';
import 'package:pokatuha/l10n/app_localizations.dart';
import 'package:pokatuha/presentation/activities/activity_detail_page.dart';
import 'package:pokatuha/presentation/activities/create_activity_page.dart';
import 'package:pokatuha/presentation/widgets/activity_card.dart';
import 'package:pokatuha/presentation/widgets/empty_state.dart';

class ActivitiesPage extends StatefulWidget {
  const ActivitiesPage({super.key});

  @override
  State<ActivitiesPage> createState() => _ActivitiesPageState();
}

class _ActivitiesPageState extends State<ActivitiesPage> {
  late Future<_ActivitiesData> _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = () async {
      final events = await serviceLocator<EventRepository>().all();
      final types = await serviceLocator<ActivityTypeRepository>().all();
      final typeMap = {for (final t in types) t.id: t.label};
      final counts = <String, int>{};
      final participants = serviceLocator<ParticipantRepository>();
      for (final e in events) {
        counts[e.id] = await participants.acceptedCount(e.id);
      }
      return _ActivitiesData(
        events: events,
        typeLabels: typeMap,
        counts: counts,
      );
    }();
  }

  List<EventCollection> _filtered(_ActivitiesData data) {
    if (_query.isEmpty) return data.events;
    final q = _query.toLowerCase();
    return data.events
        .where((e) =>
            e.title.toLowerCase().contains(q) ||
            (data.typeLabels[e.activityTypeId] ?? '')
                .toLowerCase()
                .contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(title: Text(l.tabActivities)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SearchBar(
                hintText: l.search,
                leading: const Icon(Icons.search_rounded),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
          ),
          FutureBuilder<_ActivitiesData>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final data = snapshot.data!;
              final list = _filtered(data);
              if (list.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.event_outlined,
                    title: l.noActivities,
                    subtitle: l.noActivitiesHint,
                  ),
                );
              }
              return SliverList.builder(
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final e = list[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: ActivityCard(
                      event: e,
                      activityLabel: data.typeLabels[e.activityTypeId] ?? e.activityTypeId,
                      participantCount: data.counts[e.id] ?? 0,
                      onTap: () => _open(context, e.id),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const CreateActivityPage()))
            .then((_) => setState(_load)),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  void _open(BuildContext context, String id) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(builder: (_) => ActivityDetailPage(eventId: id)),
        )
        .then((_) => setState(_load));
  }
}

class _ActivitiesData {
  _ActivitiesData({
    required this.events,
    required this.typeLabels,
    required this.counts,
  });

  final List<EventCollection> events;
  final Map<String, String> typeLabels;
  final Map<String, int> counts;
}
