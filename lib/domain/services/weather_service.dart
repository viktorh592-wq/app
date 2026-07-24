/// Weather service — Open-Meteo provider (Rule 8). Free, no API key, no
/// payment. Replaceable in the future (Product_Principles — No Vendor Lock-In).
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:pokatuha/core/errors/app_error.dart';

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
    required this.fetchedAt,
  });

  final double temperatureC;
  final double apparentTemperatureC;
  final double windSpeedKmh;
  final double windDirectionDeg;
  final double precipitationMm;
  final double rainProbability; // 0..1
  final int weatherCode;
  final bool isDay;
  final int fetchedAt; // UTC ms

  String get description => WeatherService.weatherCodeDescription(weatherCode);
}

class WeatherService {
  WeatherService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const String _baseUrl = 'https://api.open-meteo.com/v1/forecast';

  /// Current weather for a coordinate (Open-Meteo current-weather + precipitation
  /// probability). No API key required.
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
        'wind_speed_10m',
        'wind_direction_10m',
        'precipitation',
        'rain',
        'weather_code',
        'is_day',
      ].join(','),
      'daily': 'precipitation_probability_max',
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
      final daily = json['daily'] as Map<String, dynamic>?;
      final rainProbList =
          (daily?['precipitation_probability_max'] as List?)?.cast<num>();
      return WeatherSnapshot(
        temperatureC: (currentData['temperature_2m'] as num).toDouble(),
        apparentTemperatureC:
            (currentData['apparent_temperature'] as num).toDouble(),
        windSpeedKmh: (currentData['wind_speed_10m'] as num).toDouble(),
        windDirectionDeg: (currentData['wind_direction_10m'] as num).toDouble(),
        precipitationMm:
            (currentData['precipitation'] as num?)?.toDouble() ?? 0,
        rainProbability: (rainProbList != null && rainProbList.isNotEmpty
                    ? rainProbList.first
                    : 0)
                .toDouble() /
            100,
        weatherCode: (currentData['weather_code'] as num).toInt(),
        isDay: (currentData['is_day'] as num) == 1,
        fetchedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
      );
    } on AppError {
      rethrow;
    } catch (e) {
      throw CommunicationError('Weather request error: $e');
    }
  }

  /// Human-readable description for WMO weather codes (Open-Meteo).
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
