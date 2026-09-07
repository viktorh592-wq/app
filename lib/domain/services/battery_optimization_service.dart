/// Battery optimization exemption helper (V3.0.7 — user-reported bug 4).
///
/// On aggressive OEM Android variants (Xiaomi MIUI, Huawei EMUI, Oppo ColorOS,
/// Vivo FuntouchOS, Samsung OneUI in PowerSaving mode), the system kills
/// background services a few minutes after the user swipes the app away —
/// even when a foreground service is running. The chat keep-alive foreground
/// service is then destroyed, the UDP socket dies, and incoming chat messages
/// produce no notification (problem 4 root cause).
///
/// The fix is to ask the user to whitelist the app from battery optimization.
/// `permission_handler` exposes `Permission.ignoreBatteryOptimizations` which
/// opens the system settings page. We ask once on first run (after onboarding)
/// and never re-prompt after a denial — the user can re-grant from Settings.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class BatteryOptimizationService {
  BatteryOptimizationService();

  bool _askedOnce = false;

  /// True when battery-optimization exemption is granted (or not required
  /// on this platform).
  Future<bool> get isExempt async {
    if (!Platform.isAndroid) return true;
    try {
      final status = await Permission.ignoreBatteryOptimizations.status;
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// Asks the user (once per install) to whitelist the app from battery
  /// optimization. Returns true when granted. Idempotent — calling again
  /// after a denial is a no-op (the user must re-grant via system Settings).
  Future<bool> requestExemptionIfNeeded() async {
    if (_askedOnce) return await isExempt;
    _askedOnce = true;
    if (!Platform.isAndroid) return true;
    try {
      final current = await Permission.ignoreBatteryOptimizations.status;
      if (current.isGranted) return true;
      if (current.isPermanentlyDenied) return false;
      final result = await Permission.ignoreBatteryOptimizations.request();
      return result.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// Opens the system battery-optimization settings page (used from the
  /// Settings UI when the user wants to re-grant after a denial).
  Future<void> openSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await openAppSettings();
    } catch (_) {
      // Best-effort.
    }
  }

  /// Visible for tests.
  @visibleForTesting
  bool get askedOnceForTest => _askedOnce;
}
