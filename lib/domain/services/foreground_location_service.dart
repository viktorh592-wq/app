/// Foreground service wrapper — V2 MAPS_AND_GPS_FIX.md §3. Starts an
/// Android foreground service during live location sharing so the GPS
/// stream keeps flowing when the app is in the background (BR-005).
///
/// Implementation notes:
///   • Uses `flutter_foreground_task` (already declared in pubspec.yaml as
///     a Sprint 1 dependency for the same spec section).
///   • The wrapper is a no-op on platforms where the plugin is unavailable
///     (iOS, web) — those platforms fall back to plain GpsService sharing.
///   • Notification strings are localized (l10n keys `gpsForegroundTracking`
///     + `gpsForegroundTrackingBody`) — but we resolve them in the UI layer
///     (where AppLocalizations is reachable) and pass plain strings here.
library;

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'package:pokatuha/domain/services/gps_service.dart';

class ForegroundLocationService {
  bool _running = false;

  bool get isRunning => _running;

  /// Start the foreground service with the supplied localized strings.
  /// Returns whether the service started successfully (false on
  /// unsupported platforms or missing permission).
  Future<bool> start({
    required String title,
    required String body,
  }) async {
    if (_running) return true;
    try {
      await FlutterForegroundTask.startService(
        notificationTitle: title,
        notificationText: body,
      );
      _running = true;
      return true;
    } on Object {
      _running = false;
      return false;
    }
  }

  /// Stop the foreground service. Safe to call when not running.
  Future<void> stop() async {
    if (!_running) return;
    try {
      await FlutterForegroundTask.stopService();
    } on Object {
      // Ignore — platform may already be torn down.
    }
    _running = false;
  }
}

/// Adapter that combines [GpsService] with [ForegroundLocationService]:
/// starting share starts the foreground service first, stopping share
/// tears it down. Keeps the two in sync.
class LiveLocationController {
  LiveLocationController(this._gps, this._fg);

  final GpsService _gps;
  final ForegroundLocationService _fg;

  bool get isSharing => _gps.isSharing;

  Future<bool> start({
    required String fgTitle,
    required String fgBody,
  }) async {
    await _fg.start(title: fgTitle, body: fgBody);
    _gps.startSharing();
    return true;
  }

  Future<void> stop() async {
    _gps.stopSharing();
    await _fg.stop();
  }
}
