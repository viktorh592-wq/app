/// Activity Main tab — V2 structure (GROUPS_AND_ACTIVITIES.md §13,
/// ARCHITECTURE_V2.md §8, FIX_PLAN S2-T1/S2-T9): exactly four glass blocks —
/// Weather, Route summary, Participants, Actions — plus lifecycle buttons
/// (Join / Leave / Start / Finish, UC-002..UC-004) below the glass cards.
/// Activity type / date / meeting point live in the page header, not here.
/// Every GlassCard is tinted with the activity accent color (V2 §11).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:pokatuha/core/tokens/design_tokens.dart';
import 'package:pokatuha/database/collections/event_collection.dart';
import 'package:pokatuha/database/collections/route_collection.dart';
import 'package:pokatuha/domain/enums/enums.dart';
import 'package:pokatuha/domain/repositories/route_repository.dart';
import 'package:pokatuha/domain/services/service_locator.dart';
import 'package:pokatuha/l10n/app_localizations.dart';
import 'package:pokatuha/presentation/activities/activity_detail_page.dart';
import 'package:pokatuha/presentation/activities/participants_block.dart';
import 'package:pokatuha/presentation/app_view_model.dart';
import 'package:pokatuha/presentation/map/map_page.dart';
import 'package:pokatuha/presentation/weather/weather_preview.dart';
import 'package:pokatuha/presentation/widgets/elevation_profile_chart.dart';
import 'package:pokatuha/presentation/widgets/glass_card.dart';

class ActivityDetailsTab extends StatelessWidget {
  const ActivityDetailsTab({
    super.key,
    required this.event,
    required this.onAction,
    required this.onChanged,
  });

  final EventCollection event;
  final ValueChanged<EventAction> onAction;
  final VoidCallback onChanged;

  /// Activity accent color (V2 §11) — tints every glass block.
  Color get _accent {
    final argb = event.accentColor;
    return argb != null ? Color(argb) : ActivityColors.swatches.first;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final user = context.read<AppViewModel>().user;
    final isOrganizer = user?.id == event.organizerId;
    final status = EventStatus.values.firstWhere(
      (e) => e.name == event.status,
      orElse: () => EventStatus.preparation,
    );

    return ListView(
      padding: const EdgeInsets.all(DesignTokens.space4),
      children: [
        if (event.description.isNotEmpty) ...[
          Text(event.description,
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: DesignTokens.space3),
        ],

        // 1. Weather glass block (V2 §13).
        if (event.meetingPoint != null) ...[
          GlassCard(
            accentColor: _accent,
            child: WeatherPreview(
              key: ValueKey('weather-${event.id}'),
              point: event.meetingPoint!,
              eventStartAt: event.startAt,
            ),
          ),
          const SizedBox(height: DesignTokens.space3),
        ],

        // 2. Route summary block (V2 §13): distance / elevation / duration.
        FutureBuilder<List<RouteCollection>>(
          future: serviceLocator<RouteRepository>().byEvent(event.id),
          builder: (context, s) => GlassCard(
            accentColor: _accent,
            child: _routeSummary(context, s.data, l),
          ),
        ),
        const SizedBox(height: DesignTokens.space3),

        // 3. Participants block (V2 §13): avatars + live sharing count.
        GlassCard(
          accentColor: _accent,
          child: ParticipantsBlock(
            eventId: event.id,
            showInviteButton: isOrganizer,
          ),
        ),
        const SizedBox(height: DesignTokens.space3),

        // 4. Actions block (V2 §13): Open map / Share activity.
        GlassCard(
          accentColor: _accent,
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _openMap(context),
                  icon: const Icon(Icons.map_outlined),
                  label: Text(l.openMap),
                ),
              ),
              const SizedBox(width: DesignTokens.space3),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _shareActivity(),
                  icon: const Icon(Icons.share_rounded),
                  label: Text(l.shareActivity),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: DesignTokens.space4),

        // Lifecycle actions stay OUTSIDE the glass cards (V2 §13).
        _actions(context, isOrganizer, status, l),
      ],
    );
  }

  Widget _routeSummary(
    BuildContext context,
    List<RouteCollection>? routes,
    AppLocalizations l,
  ) {
    if (routes == null || routes.isEmpty) {
      return Row(
        children: [
          const Icon(Icons.route_outlined, size: 20),
          const SizedBox(width: DesignTokens.space2),
          Expanded(child: Text(l.noRouteYet)),
        ],
      );
    }
    final route = routes.first;
    final distanceKm = route.distanceMeters / 1000;
    // Rough estimate at 20 km/h average (route planning heuristic).
    final minutes = (distanceKm / 20 * 60).round();
    final duration = minutes >= 60
        ? '${minutes ~/ 60} ч ${minutes % 60} мин'
        : '$minutes мин';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.route, style: DesignTokens.title()),
        const SizedBox(height: DesignTokens.space2),
        _InfoRow(
          icon: Icons.straighten_rounded,
          text: '${l.distance}: ${distanceKm.toStringAsFixed(1)} ${l.kmUnit}',
        ),
        _InfoRow(
          icon: Icons.terrain_rounded,
          text:
              '${l.elevation}: ↑ ${route.elevationGainMeters.round()} ${l.mUnit}',
        ),
        _InfoRow(
          icon: Icons.access_time_rounded,
          text: '${l.duration}: $duration',
        ),
        const SizedBox(height: DesignTokens.space3),
        // Elevation profile graph (V3 fix — user-requested «Высоты» chart).
        ElevationProfileChart(
          points: route.waypoints,
          accentColor: _accent,
          height: 160,
        ),
      ],
    );
  }

  void _openMap(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MapPage()),
    );
  }

  void _shareActivity() {
    // V2 §9 — activity share link (pokatuha://a/<id>).
    Share.share('pokatuha://a/${event.id}', subject: event.title);
  }

  Widget _actions(
    BuildContext context,
    bool isOrganizer,
    EventStatus status,
    AppLocalizations l,
  ) {
    switch (status) {
      case EventStatus.archived:
      case EventStatus.cancelled:
        return const SizedBox.shrink();
      case EventStatus.ride:
        if (isOrganizer) {
          return FilledButton.icon(
            onPressed: () {
              onAction(EventAction.finishRide);
              onChanged();
            },
            icon: const Icon(Icons.flag_outlined),
            label: Text(l.finishRide),
          );
        }
        return const SizedBox.shrink();
      default:
        return Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () {
                  onAction(EventAction.join);
                  onChanged();
                },
                icon: const Icon(Icons.check_rounded),
                label: Text(l.join),
              ),
            ),
            const SizedBox(width: DesignTokens.space3),
            if (isOrganizer) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    onAction(EventAction.startRide);
                    onChanged();
                  },
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(l.startRide),
                ),
              ),
            ] else ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    onAction(EventAction.leave);
                    onChanged();
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: Text(l.leave),
                ),
              ),
            ],
          ],
        );
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DesignTokens.space1),
      child: Row(
        children: [
          Icon(icon, size: 20, color: DesignTokens.textPrimary),
          const SizedBox(width: DesignTokens.space2),
          Text(text, style: DesignTokens.body(color: DesignTokens.textPrimary)),
        ],
      ),
    );
  }
}
