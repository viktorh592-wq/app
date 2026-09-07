/// Pokatuha application entry point (Local-First — ADR-001).
///
/// Initializes the local database (Sembast, ADR-005), wires the service
/// locator and boots the Flutter app. FCM is used ONLY for wake-up (ADR-003);
/// all user data stays on the device; WebRTC powers Live Mode (ADR-002).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:pokatuha/app.dart';
import 'package:pokatuha/domain/services/service_locator.dart';
import 'package:pokatuha/domain/services/system_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  await setupServiceLocator();

  // V2 MAPS_AND_GPS_FIX.md §3 — the Android foreground service is started
  // on demand by `ForegroundLocationService` when the user enables live
  // location sharing (BR-005).
  //
  // V3.0.5 (bug 1) — status-bar notifications for chat messages received
  // while the app is in the background, plus the keep-alive infrastructure
  // (plugin init + communication port are set up here; the service itself
  // is started from the widget layer once localized strings exist).
  await serviceLocator<SystemNotificationService>().init();
  unawaited(serviceLocator<SystemNotificationService>().requestPermission());

  runApp(const PokatuhaApp());
}
