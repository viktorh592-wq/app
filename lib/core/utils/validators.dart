/// Data validation rules (Data_Validation.md).
class Validators {
  Validators._();

  /// Strings must be trimmed and non-empty.
  static bool isNonEmptyTrimmed(String? value) {
    if (value == null) return false;
    final trimmed = value.trim();
    return trimmed.isNotEmpty;
  }

  /// Latitude range: -90 to +90.
  static bool isValidLatitude(double lat) => lat >= -90.0 && lat <= 90.0;

  /// Longitude range: -180 to +180.
  static bool isValidLongitude(double lng) => lng >= -180.0 && lng <= 180.0;

  /// Speed cannot be negative.
  static bool isValidSpeed(double speed) => speed >= 0.0;

  /// Battery 0–100%.
  static bool isValidBattery(int level) => level >= 0 && level <= 100;

  /// Empty messages forbidden; max length configurable.
  static bool isValidMessage(String text, {int maxLength = 4096}) {
    final trimmed = text.trim();
    return trimmed.isNotEmpty && trimmed.length <= maxLength;
  }

  /// Poll must contain at least two options (Data_Validation.md).
  static bool isValidPollOptions(List<String> options) {
    final clean = options.where((o) => o.trim().isNotEmpty).toList();
    return clean.length >= 2;
  }

  /// Route must contain at least one point (Data_Validation.md).
  static bool isValidRoutePoints(List<({double lat, double lng})> points) {
    if (points.isEmpty) return false;
    return points
        .every((p) => isValidLatitude(p.lat) && isValidLongitude(p.lng));
  }

  /// Max participants must be positive when set.
  static bool isValidMaxParticipants(int? value) {
    if (value == null) return true;
    return value > 0;
  }

  /// Date must be valid UTC and not null.
  static bool isValidUtcMillis(int? value) => value != null && value > 0;
}
