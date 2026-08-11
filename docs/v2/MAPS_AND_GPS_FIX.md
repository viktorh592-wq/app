# Pokatuha V2 — Maps and GPS

Status: APPROVED
Depends on: ARCHITECTURE_V2.md, design_tokens.md

---

## 1. Supported map layers

| Map | Type | API Key |
|-----|------|---------|
| OpenStreetMap | Base / Fallback | None |
| CyclOSM | Cycling default | None |
| OpenTopoMap | Relief / Heights | None |
| Esri Satellite | Satellite | None |
| Carto Voyager | Clean navigation | None |

**Google Maps is NOT supported** (requires API key and violates ToS for direct tile usage).

### Defaults by context
- Cycling: CyclOSM
- Mountains: OpenTopoMap
- Forest: Esri Satellite
- City: Carto Voyager
- Fallback: OpenStreetMap

---

## 2. Android GPS Permissions

Required in `AndroidManifest.xml`:
- `ACCESS_FINE_LOCATION`
- `ACCESS_COARSE_LOCATION`
- `ACCESS_BACKGROUND_LOCATION` (for live tracking during activity)
- `POST_NOTIFICATIONS` (Android 13+)
- Foreground service declaration for live tracking

---

## 3. Implementation hints (Dart snippets)

### Permission request
```dart
import 'package:geolocator/geolocator.dart';

Future<bool> handleLocationPermission() async {
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) return false;

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) return false;
  }
  if (permission == LocationPermission.deniedForever) return false;
  return true;
}
```

### Position stream
```dart
final positionStream = Geolocator.getPositionStream(
  locationSettings: const LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10, // meters
  ),
).listen((Position position) {
  // Update user marker on map
  // Broadcast to activity peers via P2P
});
```

### Foreground service (Android)
Declare in `AndroidManifest.xml`:
```xml
<service
  android:name="com.pravera.flutter_foreground_task.ForegroundService"
  android:foregroundServiceType="location"
  android:exported="false" />
```

Use `flutter_foreground_task` package to keep location updates when app in background during active activity.

---

## 4. Live location

Rules:
- Only inside an active activity
- Only after user presses «Поделиться местоположением»
- Circular avatars with activity-color ring (see design_tokens.md `--map-avatar-ring`)
- Heading arrow + speed popup

### Participant popup on tap
- Name
- Status text (e.g. «Едет к месту сбора»)
- Speed (км/ч)
- Distance to me
- Heading (e.g. «↗ Северо-восток»)
- Battery (%)

---

## 5. Map action menu (FAB / three-dot)

Actions:
- Найти меня
- Поделиться местоположением
- Показать маршрут
- Скачать GPX
- Выбрать карту
- Показать участников

---

## 6. Visual behavior

- Auto-center on «Найти меня»
- Route polyline uses activity accent color
- Cluster overlapping participant icons when zoomed out
- Save selected map layer to local settings (Sembast)
- 15-minute periodic sync fallback if FCM wake-up fails
