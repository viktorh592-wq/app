/// Pokatuha application entry point (Local-First — ADR-001).
///
/// Initializes the local database (Sembast, ADR-005), wires the service
/// locator and boots the Flutter app. FCM is used for wake-up + lightweight
/// chat-metadata push (ADR-003 — V3.0.7 extends it to carry groupId /
/// eventId / authorName so notifications work even when the foreground
/// service was killed); all user data stays on the device; WebRTC powers
/// Live Mode (ADR-002), MQTT relay powers cross-network chat (ADR-009).
///
/// V3.0.8 hotfix — boot hardening. A release build renders a permanent
/// white screen when an uncaught exception kills main() before runApp()
/// (the launch theme stays on screen forever). The v3.0.7 build crashed
/// exactly this way — `FirebaseMessaging.instance` threw synchronously
/// because `Firebase.initializeApp()` had never run (see
/// fcm_push_service.dart). Every startup step is now guarded and any
/// future failure surfaces a READABLE error screen instead of white void.
import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:pokatuha/app.dart';
import 'package:pokatuha/domain/services/battery_optimization_service.dart';
import 'package:pokatuha/domain/services/fcm_push_service.dart';
import 'package:pokatuha/domain/services/service_locator.dart';
import 'package:pokatuha/domain/services/system_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- V3.0.8 hotfix: global error routing -------------------------------
  // Without these, any async error during boot escapes and the launcher
  // keeps showing the white launch theme; build() crashes render nothing
  // at all in release mode. With these, errors are logged and the UI
  // keeps running (or shows the readable boot error screen below).
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    // Handled: keep the isolate (and the UI) alive.
    return true;
  };
  ErrorWidget.builder = (FlutterErrorDetails details) {
    // Release-mode replacement for the grey/white error page.
    return const _BootErrorScreen();
  };

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // V3.0.8 hotfix — if the database or any service fails to wire up, run
  // the app anyway with a visible error screen. A permanent white screen
  // gives the user zero diagnostics; a message gives a reportable symptom.
  try {
    await setupServiceLocator();
  } on Object {
    runApp(const _BootErrorScreen());
    return;
  }

  // V3.0.5 (bug 1) — status-bar notifications for chat messages received
  // while the app is in the background, plus the keep-alive infrastructure
  // (plugin init + communication port are set up here; the service itself
  // is started from the widget layer once localized strings exist).
  // V3.0.8 hotfix — never let a notification-plugin failure kill main().
  try {
    await serviceLocator<SystemNotificationService>().init();
    unawaited(serviceLocator<SystemNotificationService>().requestPermission());
  } catch (_) {
    // Notifications are best-effort — chat keeps working without them.
  }

  // V3.0.7 (bug 3 & 4) — initialize FCM for wake-up push notifications.
  // The FCM token is shared peer-to-peer (never uploaded to any backend).
  // Battery-optimization exemption is requested so the foreground service
  // survives aggressive OEM Doze on Xiaomi / Huawei / Oppo.
  //
  // V3.0.8 hotfix — init() now runs Firebase.initializeApp() BEFORE any
  // FirebaseMessaging access (white-screen root cause) and swallows every
  // failure internally, so these unawaited calls can never abort boot.
  unawaited(serviceLocator<FcmPushService>().init());
  unawaited(
      serviceLocator<BatteryOptimizationService>().requestExemptionIfNeeded());

  runApp(const PokatuhaApp());
}

/// Readable fallback screen shown when boot fails or a release-mode build
/// error occurs. Dark, framed and textual — never a bare white void.
class _BootErrorScreen extends StatelessWidget {
  const _BootErrorScreen();

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFF121212);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const Scaffold(
        backgroundColor: background,
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.redAccent,
                  size: 48,
                ),
                SizedBox(height: 16),
                Text(
                  'Pokatuha failed to start',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'Please restart the app. If the problem persists, '
                  'reinstall it and report this screen.',
                  style: TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                Text(
                  'v3.0.8 — boot guard',
                  style: TextStyle(color: Colors.white24, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
