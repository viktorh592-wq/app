/// Weather preview — Open-Meteo (Rule 8). Free, no API key. Shown inside the
/// weather glass block of the activity Main tab (FR-001 — Weather Preview,
/// V2 GROUPS_AND_ACTIVITIES.md §13). Renders plain content — the surrounding
/// GlassCard provides the surface.
///
/// V3 fix (user-reported):
///   • Stale data on 2nd event — fixed by re-fetching in `didUpdateWidget`
///     whenever the coordinate changes, and by giving callers an explicit
///     `key: ValueKey(event.id)` so Flutter can't reuse the State across
///     different activities.
///   • English text — replaced with localized strings via AppLocalizations
///     and [localizedWeatherDescription].
///   • Forecast was daily-only — now renders the full 24-hour hourly strip
///     (temperature + icon + precipitation %) as a horizontal scroller.
import 'package:flutter/material.dart';

import 'package:pokatuha/core/errors/app_error.dart';
import 'package:pokatuha/database/collections/embedded/geo_point.dart';
import 'package:pokatuha/domain/services/service_locator.dart';
import 'package:pokatuha/domain/services/weather_service.dart';
import 'package:pokatuha/l10n/app_localizations.dart';
import 'package:pokatuha/presentation/weather/weather_helpers.dart';

class WeatherPreview extends StatefulWidget {
  const WeatherPreview({
    super.key,
    required this.point,
    this.eventStartAt,
  });

  final GeoPoint point;

  /// Optional activity start time (UTC ms). When provided and the activity
  /// is scheduled later today, the strip scrolls to highlight the matching
  /// hour. Null → current conditions only, strip starts from "now".
  final int? eventStartAt;

  @override
  State<WeatherPreview> createState() => _WeatherPreviewState();
}

class _WeatherPreviewState extends State<WeatherPreview> {
  late Future<WeatherSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  @override
  void didUpdateWidget(covariant WeatherPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-fetch when the coordinate changes (e.g. when the parent rebuilds
    // with a different event's meeting point). This prevents the widget
    // from showing the previous activity's weather.
    if (oldWidget.point.lat != widget.point.lat ||
        oldWidget.point.lng != widget.point.lng) {
      _future = _fetch();
    }
  }

  Future<WeatherSnapshot> _fetch() {
    return serviceLocator<WeatherService>().current(
      latitude: widget.point.lat,
      longitude: widget.point.lng,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WeatherSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 64,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final l = AppLocalizations.of(context)!;
        if (snapshot.hasError) {
          final msg = snapshot.error is AppError
              ? (snapshot.error as AppError).message
              : l.weatherUnavailable;
          return Row(
            children: [
              const Icon(Icons.cloud_off_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Text(msg, style: Theme.of(context).textTheme.bodyMedium),
              ),
            ],
          );
        }
        final w = snapshot.data!;
        return _Body(snapshot: w, eventStartAt: widget.eventStartAt);
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.snapshot, this.eventStartAt});

  final WeatherSnapshot snapshot;
  final int? eventStartAt;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final w = snapshot;
    final windDir = localizedWindDirection(l, w.windDirectionDeg);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Current conditions — icon + temp + description + wind/humidity.
        Row(
          children: [
            Icon(_icon(w.weatherCode),
                size: 40, color: theme.colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${w.temperatureC.round()}°C',
                      style: theme.textTheme.titleLarge),
                  Text(
                    localizedWeatherDescription(l, w.weatherCode),
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(
                    '${l.weatherWind}: ${w.windSpeedKmh.round()} км/ч $windDir • '
                    '${l.weatherHumidity}: ${w.humidity}%',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        // Rain alert banner — shown when today's max precipitation
        // probability exceeds 50%.
        if ((w.rainProbability * 100).round() >= 50) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFF48FB1),
                  const Color(0xFFE91E63).withValues(alpha: 0.85),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.umbrella_rounded, color: Colors.white,
                    size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.weatherRainAlert,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        // Hourly forecast strip — "Прогноз по часам".
        if (w.hourly.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(l.weatherHourlyForecast,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: w.hourly.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final h = w.hourly[i];
                final dt = DateTime.tryParse(h.time);
                final hourLabel = dt == null
                    ? '${i}ч'
                    : '${dt.hour.toString().padLeft(2, '0')}ч';
                return _HourCell(
                  hour: hourLabel,
                  temperature: '${h.temperatureC.round()}°',
                  icon: _icon(h.weatherCode),
                  precipitation: h.precipitationProbability,
                  highlight: _isHighlightHour(dt),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  /// Whether this hour cell should be highlighted (matches the activity
  /// start hour, or "now" if no event start was provided).
  bool _isHighlightHour(DateTime? dt) {
    if (dt == null) return false;
    if (eventStartAt == null) {
      final now = DateTime.now();
      return dt.hour == now.hour && dt.day == now.day;
    }
    final start = DateTime.fromMillisecondsSinceEpoch(eventStartAt!,
        isUtc: false);
    return dt.hour == start.hour && dt.day == start.day;
  }

  IconData _icon(int code) {
    if (code == 0) return Icons.wb_sunny_rounded;
    if (code <= 3) return Icons.cloud_outlined;
    if (code <= 67) return Icons.grain_rounded;
    if (code <= 86) return Icons.ac_unit_rounded;
    return Icons.thunderstorm_rounded;
  }
}

class _HourCell extends StatelessWidget {
  const _HourCell({
    required this.hour,
    required this.temperature,
    required this.icon,
    required this.precipitation,
    required this.highlight,
  });

  final String hour;
  final String temperature;
  final IconData icon;
  final int precipitation; // 0..100
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 56,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: highlight
            ? theme.colorScheme.primary.withValues(alpha: 0.18)
            : theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: highlight
            ? Border.all(color: theme.colorScheme.primary, width: 1.5)
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(hour, style: theme.textTheme.labelSmall),
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          Text(temperature,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          if (precipitation > 0)
            Text(
              '$precipitation%',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.blue,
                fontSize: 10,
              ),
            )
          else
            const SizedBox(height: 12),
        ],
      ),
    );
  }
}
