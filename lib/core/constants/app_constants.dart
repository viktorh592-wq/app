/// Application-wide constants for Pokatuha.
class AppConstants {
  AppConstants._();

  static const String appName = 'Pokatuha';
  static const String version = '1.0.0';

  /// Local database file name (ADR-005 — Sembast).
  static const String databaseName = 'pokatuha';

  /// 8dp spacing system (Design_Language.md).
  static const double spacingUnit = 8.0;

  /// Corner radii (Design_Language.md).
  static const double radiusCard = 16.0;
  static const double radiusDialog = 20.0;
  static const double radiusButton = 14.0;

  /// Default arrival-detection thresholds in meters (FR-006).
  static const double arrivalThresholdNear = 500.0;
  static const double arrivalThresholdClose = 200.0;
  static const double arrivalThresholdArrived = 50.0;

  /// Default chat limits (Data_Validation.md).
  static const int maxMessageLength = 4096;
  static const int minPollOptions = 2;

  /// WebRTC signaling (ADR-002) — kept abstract, no mandatory server.
  static const Duration peerConnectionTimeout = Duration(seconds: 30);
  static const Duration gpsBroadcastInterval = Duration(seconds: 3);
  static const Duration presenceInterval = Duration(seconds: 10);
}

/// Default activity types (README.md).
class DefaultActivityTypes {
  DefaultActivityTypes._();

  static const List<String> values = [
    'MTB',
    'XC',
    'Enduro',
    'Downhill',
    'Gravel',
    'Road',
    'BMX',
    'E-Bike',
    'Hiking',
    'Running',
  ];
}
