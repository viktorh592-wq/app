/// Home tab — quick overview of upcoming and live activities (US-001, US-004).
import 'package:flutter/material.dart';

import 'package:pokatuha/database/collections/event_collection.dart';
import 'package:pokatuha/domain/repositories/activity_type_repository.dart';
import 'package:pokatuha/domain/repositories/event_repository.dart';
import 'package:pokatuha/domain/repositories/participant_repository.dart';
import 'package:pokatuha/domain/services/service_locator.dart';
import 'package:pokatuha/l10n/app_localizations.dart';
import 'package:pokatuha/presentation/activities/activity_detail_page.dart';
import 'package:pokatuha/presentation/widgets/activity_card.dart';
import 'package:pokatuha/presentation/widgets/empty_state.dart';
import 'package:pokatuha/presentation/widgets/sync_banner.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<_HomeData> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final events = serviceLocator<EventRepository>();
    final participants = serviceLocator<ParticipantRepository>();
    final types = serviceLocator<ActivityTypeRepository>();
    _future = () async {
      final upcoming = await events.upcoming();
      final live = await events.live();
      final all = <EventCollection>[...live, ...upcoming];
      final typeMap = {for (final t in await types.all()) t.id: t.label};
      final counts = <String, int>{};
      for (final e in all) {
        counts[e.id] = await participants.acceptedCount(e.id);
      }
      return _HomeData(events: all, typeLabels: typeMap, counts: counts);
    }();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => setState(_load),
        child: CustomScrollView(
          slivers: [
            SliverAppBar.large(title: Text(l.tabHome)),
            const SliverToBoxAdapter(child: SyncBanner()),
            FutureBuilder<_HomeData>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final data = snapshot.data!;
                if (data.events.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.event_available_outlined,
                      title: l.noActivities,
                      subtitle: l.noActivitiesHint,
                    ),
                  );
                }
                return SliverList.builder(
                  itemCount: data.events.length,
                  itemBuilder: (context, i) {
                    final e = data.events[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: ActivityCard(
                        event: e,
                        activityLabel: data.typeLabels[e.activityTypeId] ??
                            e.activityTypeId,
                        participantCount: data.counts[e.id],
                        onTap: () => _open(context, e.id),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context, String id) {
    Navigator.of(context)
        .push(
            MaterialPageRoute(builder: (_) => ActivityDetailPage(eventId: id)))
        .then((_) => setState(_load));
  }
}

class _HomeData {
  _HomeData({
    required this.events,
    required this.typeLabels,
    required this.counts,
  });

  final List<EventCollection> events;
  final Map<String, String> typeLabels;
  final Map<String, int> counts;
}
