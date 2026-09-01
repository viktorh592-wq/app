/// Weather service — Open-Meteo provider (Rule 8). Free, no API key, no
/// payment. Replaceable in the future (Product_Principles — No Vendor Lock-In).
///
/// V3 fix: now fetches both `current=` (instant conditions) and `hourly=`
/// (full 24-hour forecast for the current day) in one request, so the UI can
/// render the "Прогноз по часам" horizontal strip. Localized descriptions
/// live in the UI layer (weatherCodeDescription in AppLocalizations) — the
/// service only returns the raw WMO code.
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:pokatuha/core/errors/app_error.dart';

/// One hourly forecast entry. Times are ISO strings from Open-Meteo
/// (already in the requested timezone when `timezone=auto`).
class HourlyForecast {
  HourlyForecast({
    required this.time,
    required this.temperatureC,
    required this.weatherCode,
    required this.precipitationProbability,
    required this.windSpeedKmh,
  });

  final String time; // ISO 8601, local to the forecast location
  final double temperatureC;
  final int weatherCode;
  final int precipitationProbability; // 0..100
  final double windSpeedKmh;
}

class WeatherSnapshot {
  WeatherSnapshot({
    required this.temperatureC,
    required this.apparentTemperatureC,
    required this.windSpeedKmh,
    required this.windDirectionDeg,
    required this.precipitationMm,
    required this.rainProbability,
    required this.weatherCode,
    required this.isDay,
    required this.humidity,
    required this.fetchedAt,
    required this.hourly,
  });

  final double temperatureC;
  final double apparentTemperatureC;
  final double windSpeedKmh;
  final double windDirectionDeg;
  final double precipitationMm;
  final double rainProbability; // 0..1
  final int weatherCode;
  final bool isDay;
  final int humidity; // %
  final int fetchedAt; // UTC ms
  final List<HourlyForecast> hourly;

  /// The original English description is kept for backward-compat callers
  /// that haven't been migrated to AppLocalizations yet. UI code should
  /// prefer [weatherCodeDescriptionLocalized] from the widget layer.
  String get description => WeatherService.weatherCodeDescription(weatherCode);
}

class WeatherService {
  WeatherService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const String _baseUrl = 'https://api.open-meteo.com/v1/forecast';

  /// Current weather + 24-hour hourly forecast for a coordinate.
  ///
  /// Open-Meteo free tier: no API key, no payment. Returns both instant
  /// conditions (current=) and the day's hourly breakdown (hourly=) so the
  /// UI can render the "Прогноз по часам" strip the user asked for.
  Future<WeatherSnapshot> current({
    required double latitude,
    required double longitude,
  }) async {
    final params = <String, String>{
      'latitude': latitude.toStringAsFixed(4),
      'longitude': longitude.toStringAsFixed(4),
      'current': [
        'temperature_2m',
        'apparent_temperature',
        'relative_humidity_2m',
        'wind_speed_10m',
        'wind_direction_10m',
        'precipitation',
        'rain',
        'weather_code',
        'is_day',
      ].join(','),
      'hourly': [
        'temperature_2m',
        'weather_code',
        'precipitation_probability',
        'wind_speed_10m',
      ].join(','),
      'forecast_days': '1',
      'timezone': 'auto',
    };
    final uri = Uri.parse(_baseUrl).replace(queryParameters: params);
    try {
      final response = await _client.get(uri);
      if (response.statusCode != 200) {
        throw CommunicationError(
            'Open-Meteo request failed: ${response.statusCode}');
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final currentData = json['current'] as Map<String, dynamic>;
      final hourlyData = json['hourly'] as Map<String, dynamic>?;

      // Parse hourly forecast — 24 entries for forecast_days=1.
      final hourly = <HourlyForecast>[];
      if (hourlyData != null) {
        final times = (hourlyData['time'] as List?)?.cast<String>() ?? const [];
        final temps =
            (hourlyData['temperature_2m'] as List?)?.cast<num>() ?? const [];
        final codes =
            (hourlyData['weather_code'] as List?)?.cast<num>() ?? const [];
        final probs = (hourlyData['precipitation_probability'] as List?)
                ?.cast<num>() ??
            const [];
        final winds =
            (hourlyData['wind_speed_10m'] as List?)?.cast<num>() ?? const [];
        final n = times.length;
        for (var i = 0; i < n; i++) {
          hourly.add(HourlyForecast(
            time: times[i],
            temperatureC: (i < temps.length ? temps[i] : 0).toDouble(),
            weatherCode: (i < codes.length ? codes[i] : 0).toInt(),
            precipitationProbability:
                (i < probs.length ? probs[i] : 0).toInt(),
            windSpeedKmh: (i < winds.length ? winds[i] : 0).toDouble(),
          ));
        }
      }

      // rainProbability: derive from today's max hourly precipitation
      // probability (0..100 -> 0..1).
      final probList = hourlyData?['precipitation_probability'] as List?;
      final maxProb = (probList == null || probList.isEmpty)
          ? 0
          : probList.cast<num>().reduce((a, b) => a > b ? a : b);
      final rainProb = (maxProb.toDouble()) / 100.0;

      return WeatherSnapshot(
        temperatureC: (currentData['temperature_2m'] as num).toDouble(),
        apparentTemperatureC:
            (currentData['apparent_temperature'] as num).toDouble(),
        windSpeedKmh: (currentData['wind_speed_10m'] as num).toDouble(),
        windDirectionDeg:
            (currentData['wind_direction_10m'] as num).toDouble(),
        precipitationMm:
            (currentData['precipitation'] as num?)?.toDouble() ?? 0,
        rainProbability: rainProb,
        weatherCode: (currentData['weather_code'] as num).toInt(),
        isDay: (currentData['is_day'] as num) == 1,
        humidity:
            (currentData['relative_humidity_2m'] as num?)?.toInt() ?? 0,
        fetchedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
        hourly: hourly,
      );
    } on AppError {
      rethrow;
    } catch (e) {
      throw CommunicationError('Weather request error: $e');
    }
  }

  /// Fallback English description for a WMO weather code (Open-Meteo).
  /// UI code should prefer the localized variant in AppLocalizations.
  static String weatherCodeDescription(int code) {
    return switch (code) {
      0 => 'Clear sky',
      1 => 'Mainly clear',
      2 => 'Partly cloudy',
      3 => 'Overcast',
      45 || 48 => 'Fog',
      51 || 53 || 55 => 'Drizzle',
      56 || 57 => 'Freezing drizzle',
      61 || 63 || 65 => 'Rain',
      66 || 67 => 'Freezing rain',
      71 || 73 || 75 => 'Snow fall',
      77 => 'Snow grains',
      80 || 81 || 82 => 'Rain showers',
      85 || 86 => 'Snow showers',
      95 => 'Thunderstorm',
      96 || 99 => 'Thunderstorm with hail',
      _ => 'Unknown',
    };
  }

  void dispose() => _client.close();
}
