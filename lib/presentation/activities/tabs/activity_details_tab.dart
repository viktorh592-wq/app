/// Activity Main tab — V2 structure (GROUPS_AND_ACTIVITIES.md §13,
/// ARCHITECTURE_V2.md §8, FIX_PLAN S2-T1/S2-T9): exactly four glass blocks —
/// Weather, Route summary, Participants, Actions — plus lifecycle buttons
/// (Join / Leave / Start / Finish, UC-002..UC-004) below the glass cards.
/// Activity type / date / meeting point live in the page header, not here.
/// Every GlassCard is tinted with the activity accent color (V2 §11).
///
/// V3.0.3 fix (user feedback):
///   • The «Join» button is only shown if the user is allowed to join the
///     activity given its visibility:
///     - public / linkOnly — any group member may join
///     - private — only if the user has been explicitly invited
///       (participant record with status = invited) OR is the organizer
///   • The «Invite» button inside the ParticipantsBlock is shown iff the
///     current user has the `canInvite` permission in the activity's group
///     (owner / admin / explicitly granted member) AND the activity is
///     not public.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:pokatuha/core/tokens/design_tokens.dart';
import 'package:pokatuha/database/collections/event_collection.dart';
import 'package:pokatuha/database/collections/route_collection.dart';
import 'package:pokatuha/domain/enums/enums.dart';
import 'package:pokatuha/domain/repositories/participant_repository.dart';
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

class ActivityDetailsTab extends StatefulWidget {
  const ActivityDetailsTab({
    super.key,
    required this.event,
    required this.onAction,
    required this.onChanged,
  });

  final EventCollection event;
  final ValueChanged<EventAction> onAction;
  final VoidCallback onChanged;

  @override
  State<ActivityDetailsTab> createState() => _ActivityDetailsTabState();
}

class _ActivityDetailsTabState extends State<ActivityDetailsTab> {
  /// V3.0.3 fix — resolved once per build cycle:
  ///   `_canInvite` — whether the current user may invite others (group
  ///     permission, not the organizer-only check).
  ///   `_mayJoin` — whether the user is allowed to join (visibility rules).
  ///   `_isParticipant` — whether the user is already a participant.
  bool _canInvite = false;
  bool _mayJoin = false;
  bool _isParticipant = false;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    _resolvePermissions();
  }

  @override
  void didUpdateWidget(covariant ActivityDetailsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.event.id != widget.event.id ||
        oldWidget.event.visibility != widget.event.visibility) {
      _resolved = false;
      _resolvePermissions();
    }
  }

  Future<void> _resolvePermissions() async {
    final user = context.read<AppViewModel>().user;
    final event = widget.event;
    if (user == null) {
      if (mounted) setState(() => _resolved = true);
      return;
    }
    final groupId = event.groupId;
    final canInvite = (groupId == null || groupId.isEmpty)
        ? false
        : await canCurrentUserInviteToGroup(groupId, user.id);
    final existingP = await serviceLocator<ParticipantRepository>()
        .byEventAndUser(event.id, user.id);
    final isParticipant = existingP != null;
    final visibility = EventVisibility.values.firstWhere(
      (v) => v.name == event.visibility,
      orElse: () => EventVisibility.private,
    );
    final isOrganizer = user.id == event.organizerId;
    final isInvited = existingP != null &&
        existingP.status == ParticipantStatus.invited.name;
    final mayJoin = !isParticipant &&
        (visibility == EventVisibility.public ||
            visibility == EventVisibility.linkOnly ||
            isInvited ||
            isOrganizer);
    if (mounted) {
      setState(() {
        _canInvite = canInvite;
        _mayJoin = mayJoin;
        _isParticipant = isParticipant;
        _resolved = true;
      });
    }
  }

  /// Activity accent color (V2 §11) — tints every glass block.
  Color get _accent {
    final argb = widget.event.accentColor;
    return argb != null ? Color(argb) : ActivityColors.swatches.first;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final user = context.read<AppViewModel>().user;
    final isOrganizer = user?.id == widget.event.organizerId;
    final status = EventStatus.values.firstWhere(
      (e) => e.name == widget.event.status,
      orElse: () => EventStatus.preparation,
    );

    return ListView(
      padding: const EdgeInsets.all(DesignTokens.space4),
      children: [
        if (widget.event.description.isNotEmpty) ...[
          Text(widget.event.description,
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: DesignTokens.space3),
        ],

        // 1. Weather glass block (V2 §13).
        if (widget.event.meetingPoint != null) ...[
          GlassCard(
            accentColor: _accent,
            child: WeatherPreview(
              key: ValueKey('weather-${widget.event.id}'),
              point: widget.event.meetingPoint!,
              eventStartAt: widget.event.startAt,
            ),
          ),
          const SizedBox(height: DesignTokens.space3),
        ],

        // 2. Route summary block (V2 §13): distance / elevation / duration.
        FutureBuilder<List<RouteCollection>>(
          future: serviceLocator<RouteRepository>().byEvent(widget.event.id),
          builder: (context, s) => GlassCard(
            accentColor: _accent,
            child: _routeSummary(context, s.data, l),
          ),
        ),
        const SizedBox(height: DesignTokens.space3),

        // 3. Participants block (V2 §13): avatars + live sharing count.
        // V3.0.3 fix — pass the full event + the resolved `canInvite`
        // flag so the block can decide whether to show the «Invite»
        // button. The organizer also always has the invite right.
        GlassCard(
          accentColor: _accent,
          child: ParticipantsBlock(
            event: widget.event,
            showInviteButton: isOrganizer,
            canInvite: _canInvite,
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
        // V3.0.3 fix — Join is only shown if `_mayJoin` is true
        // (visibility rules). Leave is shown if the user is already a
        // participant.
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
    Share.share('pokatuha://a/${widget.event.id}', subject: widget.event.title);
  }

  Widget _actions(
    BuildContext context,
    bool isOrganizer,
    EventStatus status,
    AppLocalizations l,
  ) {
    if (!_resolved) {
      return const SizedBox(
        height: 24,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    switch (status) {
      case EventStatus.archived:
      case EventStatus.cancelled:
        return const SizedBox.shrink();
      case EventStatus.ride:
        if (isOrganizer) {
          return FilledButton.icon(
            onPressed: () {
              widget.onAction(EventAction.finishRide);
              widget.onChanged();
            },
            icon: const Icon(Icons.flag_outlined),
            label: Text(l.finishRide),
          );
        }
        return const SizedBox.shrink();
      default:
        return Row(
          children: [
            // V3.0.3 fix — Join is only shown when allowed by visibility.
            if (_mayJoin) ...[
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    widget.onAction(EventAction.join);
                    widget.onChanged();
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: Text(l.join),
                ),
              ),
              const SizedBox(width: DesignTokens.space3),
            ] else if (_isParticipant && !isOrganizer) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    widget.onAction(EventAction.leave);
                    widget.onChanged();
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: Text(l.leave),
                ),
              ),
              const SizedBox(width: DesignTokens.space3),
            ],
            if (isOrganizer) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    widget.onAction(EventAction.startRide);
                    widget.onChanged();
                  },
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(l.startRide),
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
