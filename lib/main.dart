/// Pokatuha application entry point (Local-First — ADR-001).
///
/// Initializes the local database (Sembast, ADR-005), wires the service
/// locator and boots the Flutter app. FCM is used ONLY for wake-up (ADR-003);
/// all user data stays on the device; WebRTC powers Live Mode (ADR-002).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:pokatuha/app.dart';
import 'package:pokatuha/domain/services/service_locator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  await setupServiceLocator();

  // V2 MAPS_AND_GPS_FIX.md §3 — the Android foreground service is started
  // on demand by `ForegroundLocationService` when the user enables live
  // location sharing (BR-005). No startup init needed — see
  // `lib/domain/services/foreground_location_service.dart`.

  runApp(const PokatuhaApp());
}
