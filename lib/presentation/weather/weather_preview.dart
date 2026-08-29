/// Weather preview — Open-Meteo (Rule 8). Free, no API key. Shown inside the
/// weather glass block of the activity Main tab (FR-001 — Weather Preview,
/// V2 GROUPS_AND_ACTIVITIES.md §13). Renders plain content — the surrounding
/// GlassCard provides the surface.
import 'package:flutter/material.dart';

import 'package:pokatuha/core/errors/app_error.dart';
import 'package:pokatuha/database/collections/embedded/geo_point.dart';
import 'package:pokatuha/domain/services/service_locator.dart';
import 'package:pokatuha/domain/services/weather_service.dart';

class WeatherPreview extends StatefulWidget {
  const WeatherPreview({super.key, required this.point});

  final GeoPoint point;

  @override
  State<WeatherPreview> createState() => _WeatherPreviewState();
}

class _WeatherPreviewState extends State<WeatherPreview> {
  late Future<WeatherSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _future = serviceLocator<WeatherService>().current(
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
        if (snapshot.hasError) {
          final msg = snapshot.error is AppError
              ? (snapshot.error as AppError).message
              : 'Weather unavailable';
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
        return Row(
          children: [
            Icon(_icon(w.weatherCode),
                size: 40, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${w.temperatureC.round()}°C',
                      style: Theme.of(context).textTheme.titleLarge),
                  Text(w.description,
                      style: Theme.of(context).textTheme.bodyMedium),
                  Text(
                    '💨 ${w.windSpeedKmh.round()} km/h • 🌧 ${(w.rainProbability * 100).round()}%',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  IconData _icon(int code) {
    if (code == 0) return Icons.wb_sunny_rounded;
    if (code <= 3) return Icons.cloud_outlined;
    if (code <= 67) return Icons.grain_rounded;
    if (code <= 86) return Icons.ac_unit_rounded;
    return Icons.thunderstorm_rounded;
  }
}
