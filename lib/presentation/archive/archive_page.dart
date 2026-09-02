/// Archive tab — completed activities stored locally (FR-009, UC-004).
/// Archived rides are never soft-deleted automatically (Soft_Delete.md).
/// V3.0.3 fix — archive items are now tappable: opens the activity detail
/// page in read-only mode (user-reported Доп. 2: «archived activities
/// don't open for reading»).
import 'package:flutter/material.dart';

import 'package:pokatuha/core/utils/timestamps.dart';
import 'package:pokatuha/database/collections/archive_collection.dart';
import 'package:pokatuha/domain/repositories/archive_repository.dart';
import 'package:pokatuha/domain/services/service_locator.dart';
import 'package:pokatuha/l10n/app_localizations.dart';
import 'package:pokatuha/presentation/activities/activity_detail_page.dart';
import 'package:pokatuha/presentation/widgets/empty_state.dart';

class ArchivePage extends StatefulWidget {
  const ArchivePage({super.key});

  @override
  State<ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends State<ArchivePage> {
  late Future<List<ArchiveCollection>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = serviceLocator<ArchiveRepository>().all();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    // V3.0.3 fix — use the active locale for date formatting instead of
    // hardcoded 'en' (user-reported Issue 5).
    final localeCode = Localizations.localeOf(context).languageCode;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => setState(_load),
        child: CustomScrollView(
          slivers: [
            SliverAppBar.large(title: Text(l.tabArchive)),
            FutureBuilder<List<ArchiveCollection>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final list = snapshot.data!;
                if (list.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.history_rounded,
                      title: l.noArchive,
                    ),
                  );
                }
                return SliverList.builder(
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final a = list[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: InkWell(
                        onTap: () => _openArchive(context, a),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(a.title,
                                        style: theme.textTheme.titleMedium),
                                  ),
                                  Icon(
                                    Icons.history_rounded,
                                    size: 18,
                                    color: theme.colorScheme.outline,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                Timestamps.formatLocalDate(
                                    a.rideFinishedAt, localeCode),
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 16,
                                runSpacing: 4,
                                children: [
                                  _stat(l.distance,
                                      '${(a.distanceMeters / 1000).toStringAsFixed(1)} km'),
                                  _stat(l.duration,
                                      '${(a.durationSeconds / 60).round()} min'),
                                  _stat(l.elevation,
                                      '${a.elevationGainMeters.round()} m'),
                                  _stat(l.avgSpeed,
                                      '${(a.averageSpeed * 3.6).toStringAsFixed(1)} km/h'),
                                ],
                              ),
                            ],
                          ),
                        ),
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

  /// V3.0.3 fix — open the archived activity in the ActivityDetailPage.
  /// The event record is still in the EventRepository (just with status
  /// 'archived'), so the detail page renders in read-only mode (the
  /// lifecycle buttons are hidden for archived status — see
  /// ActivityDetailsTab._actions).
  void _openArchive(BuildContext context, ArchiveCollection archive) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActivityDetailPage(eventId: archive.eventId),
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: Theme.of(context).textTheme.titleSmall),
        Text(label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )),
      ],
    );
  }
}
