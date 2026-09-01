/// Weather UI helpers — maps WMO weather codes (Open-Meteo) to localized
/// strings declared in app_ru.arb / app_en.arb. Lives in the UI layer
/// because the WeatherService (domain) is not allowed to import Flutter /
/// AppLocalizations.
import 'package:pokatuha/l10n/app_localizations.dart';

/// Returns the localized description for an Open-Meteo WMO weather code.
String localizedWeatherDescription(AppLocalizations l, int code) {
  return switch (code) {
    0 => l.weatherClearSky,
    1 => l.weatherMainlyClear,
    2 => l.weatherPartlyCloudy,
    3 => l.weatherOvercast,
    45 || 48 => l.weatherFog,
    51 || 53 || 55 => l.weatherDrizzle,
    56 || 57 => l.weatherFreezingDrizzle,
    61 || 63 || 65 => l.weatherRain,
    66 || 67 => l.weatherFreezingRain,
    71 || 73 || 75 => l.weatherSnowFall,
    77 => l.weatherSnowGrains,
    80 || 81 || 82 => l.weatherRainShowers,
    85 || 86 => l.weatherSnowShowers,
    95 => l.weatherThunderstorm,
    96 || 99 => l.weatherThunderstormHail,
    _ => l.weatherUnknown,
  };
}

/// Compass direction text for a wind bearing (degrees 0..360), localized
/// via AppLocalizations heading keys.
String localizedWindDirection(AppLocalizations l, double bearing) {
  final b = (bearing + 360) % 360;
  if (b >= 337.5 || b < 22.5) return l.mapHeadingN;
  if (b < 67.5) return l.mapHeadingNE;
  if (b < 112.5) return l.mapHeadingE;
  if (b < 157.5) return l.mapHeadingSE;
  if (b < 202.5) return l.mapHeadingS;
  if (b < 247.5) return l.mapHeadingSW;
  if (b < 292.5) return l.mapHeadingW;
  return l.mapHeadingNW;
}
