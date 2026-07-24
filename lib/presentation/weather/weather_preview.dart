/// Weather preview — Open-Meteo (Rule 8). Free, no API key. Shown in activity
/// details (FR-001 — Weather Preview) and maps.
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
    final theme = Theme.of(context);
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
          return Card(
            child: ListTile(
              leading: const Icon(Icons.cloud_off_outlined),
              title: Text(msg, style: theme.textTheme.bodyMedium),
              dense: true,
            ),
          );
        }
        final w = snapshot.data!;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
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
                      Text(w.description, style: theme.textTheme.bodyMedium),
                      Text(
                        '💨 ${w.windSpeedKmh.round()} km/h • 🌧 ${(w.rainProbability * 100).round()}%',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
