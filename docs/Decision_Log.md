# Decision Log

Version: 1.0.0

Status: ACTIVE

Purpose

This document records every important project decision in chronological order.

Unlike ADR documents, this file also tracks feature changes, requirement updates, and implementation notes.

---

## 2026-07-24

### Project Created

Status

Accepted

Description

Pokatuha project initialized.

---

### Architecture

Accepted

Local-First architecture selected.

Reference

ADR-001

---

### Communication

Accepted

Two communication modes approved.

Live Mode

WebRTC

Sleep Mode

Firebase Cloud Messaging

Reference

ADR-002

ADR-003

---

### Database

Accepted

Primary database

Isar

Reference

ADR-004

---

### Database (revision)

Accepted

Isar v3 generator is incompatible with the supported Dart 3.8 toolchain
(unmaintained since 2023; v4 is dev-only). Storage engine switched to Sembast
(pure-Dart, offline-first, no codegen). All Local-First invariants and entity
standards preserved. Collection class/field names unchanged.

Reference

ADR-005

---

### Weather

Accepted

Provider

Open-Meteo

Reason

Free

No API key

---

### Maps

Accepted

Default

OpenStreetMap

MapLibre

Future providers

Google Maps

HERE

2GIS

Yandex Maps

---

### Ride Archive

Accepted

Completed rides move automatically into archive.

Archive includes

Chat

Photos

Videos

GPX

Statistics

Timeline

---

### Polls

Accepted

Multiple simultaneous polls allowed.

Supported

Time

Meeting Point

Route

Distance

Custom questions

---

### GPS

Accepted

Sharing begins only after Start Ride.

---

### Arrival Notifications

Accepted

Automatic notifications

500 meters

200 meters

Arrived

Configurable thresholds.

---

### Themes

Accepted

Telegram-like customization system.

User may customize:

Accent color

Icons

Theme

Map style

Future fonts

---

## 2026-08-30

### Sprint 4 — Maps and GPS (V2 MAPS_AND_GPS_FIX.md)

Status

Accepted

Description

Sprint 4 implements the V2 map layer set, enhanced GPS sharing with
foreground service, and the V2 participant-marker experience.

Tasks (S4-T1..T12):

- S4-T1 — MapProvider enum extended with the five V2 providers
  (cyclOSM, openTopoMap, esriSatellite, cartoVoyager).
  Deprecated non-V2 vendors (googleMaps, here, twoGis, yandexMaps,
  mapLibre) remain selectable for back-compat with persisted settings
  and fall back to OSM tiles. Google Maps is explicitly forbidden by
  V2 spec (API key + ToS violation).
- S4-T2 — MapService.defaultProviderFor(activityType) selects the
  context-aware default layer (cycling to CyclOSM, mountains to
  OpenTopoMap, forest/water to Esri Satellite, city to Carto Voyager,
  fallback to OSM).
- S4-T3 — Layer switcher UI rebuilt with all five V2 providers; each
  entry shows a localized context hint. Selection persists via
  SettingsService (V2 section 6).
- S4-T4 — Participant marker rewritten as a circular avatar ringed
  with the activity accent color, with a heading arrow (rotated by
  bearing) and a speed badge in km/h (V2 section 4).
- S4-T5 — Participant popup sheet on marker tap: name, status text,
  speed (km/h), heading text (compass direction localized),
  battery percent.
- S4-T6 — Marker clustering when zoomed out: below zoom 14,
  overlapping participant markers within 1 km merge into a single
  count badge (V2 section 6).
- S4-T7 — AndroidManifest.xml updated with ACCESS_FINE_LOCATION,
  ACCESS_COARSE_LOCATION, ACCESS_BACKGROUND_LOCATION,
  POST_NOTIFICATIONS, FOREGROUND_SERVICE,
  FOREGROUND_SERVICE_LOCATION, plus the foreground service
  declaration for flutter_foreground_task (V2 sections 2, 3).
- S4-T8 — ForegroundLocationService wraps flutter_foreground_task
  (already in pubspec.yaml). Started when the user enables live
  sharing, stopped when sharing ends. No-op on platforms where the
  plugin is unavailable.
- S4-T9 — 15-minute periodic fallback timer re-emits lastSeenAt
  via ParticipantRepository.touchLastSeen so map timestamps stay
  fresh for viewers when the sharing user has not moved (V2 section 6).
- S4-T10 — l10n keys added (en + ru) for CyclOSM / OpenTopoMap /
  Esri Satellite / Carto Voyager labels, context hints, permission
  strings, foreground service notification title/body, participant
  popup labels and compass-direction texts.
- S4-T11 — Unit tests for MapService: tile URL composition for every
  V2 provider, context-aware default selection across EN and RU
  activity-type strings, provider switching.
- S4-T12 — This Decision Log entry.

Reference

V2 MAPS_AND_GPS_FIX.md sections 1 to 6

ADR-002 (WebRTC — P2P propagation of live GPS stays a future
sprint; the S4-T3 P2P-sync note in earlier code comments is replaced
by S4-T9 local periodic fallback for now.)

---

## 2026-08-30 — Sprint 6 — V3.0.0 Release Hardening

Status

Accepted

Description

Sprint 6 is the release-hardening sprint that closes the V2 specification
work and prepares the project for the V3.0.0 release. Full architectural
record: adr/ADR-006-Sprint-6-Release-Hardening.md.

Tasks (S6-T1..T7):

- S6-T1 — Build Flutter APK CI fix. Root cause: `record 5.2.1` (what
  `^5.1.2` resolves to) declares `record_platform_interface: ^1.2.0`
  and `record_linux: >=0.5.0 <1.0.0`; pub resolved them to `1.6.0`
  and `0.7.2`. Empirical verification showed the breakage is older
  than initially supposed: `record_platform_interface 1.5.0` already
  moved `startStream` into a new abstract class
  `RecordMethodChannelPlatformInterface` and changed the
  `hasPermission` signature; `record_linux 0.7.2` (last touched
  2024-06-26) does not implement either. Since `record_android ^1.5.0`
  and `record_web ^1.5.0` require `>= 1.5.0` but `record_linux 0.7.2`
  is only compatible with `<= 1.1.0`, the dependency graph is
  genuinely unsatisfiable within `record 5.x`. Fix: remove `record`
  and `just_audio` from `pubspec.yaml` entirely — both packages were
  declared for the future voice-message feature (TELEGRAM_STYLE_CHAT.md
  §9) but never actually imported by any `lib/` or `test/` file. The
  12 transitive entries (`record_android`, `record_darwin`,
  `record_linux`, `record_platform_interface`, `record_web`,
  `record_windows`, `just_audio_platform_interface`, `just_audio_web`,
  `audio_session`, `rxdart`) were pruned from `pubspec.lock`.
  `crypto` is kept because `uuid 4.6.0` still pulls it. When S3-T6
  voice messages are actually implemented, a future sprint should
  re-add `record: ^7.x` (which pulls the maintained `record_linux 1.x`).
- S6-T2 — `pubspec.yaml` version bumped `1.0.0+1` -> `3.0.0+1` to
  signal the V3.0.0 release milestone.
- S6-T3 (S5-T5) — README updated (Version 3.0.0, sprint status table,
  expanded repository structure); this Decision_Log entry; new
  `adr/ADR-006-Sprint-6-Release-Hardening.md` recording the
  architectural decisions for the sprint.
- S6-T4 (S5-T6) — Dead code removal. Two unreferenced library files
  deleted: `lib/core/errors/result.dart` (Result/Failure/Success sealed
  type, no call site) and `lib/core/extensions/iterable_extensions.dart`
  (mapIndexed/firstWhereOrNull, no call site; codebase uses Dart 3.0+
  `Iterable.firstOrNull` instead).
- S6-T5 (S4-T6) — Marker clustering. Already implemented in
  `MapPage._participantMarkers` as a custom distance-based greedy
  algorithm (zoom < 14, threshold 1 km, count badge with tap-to-zoom).
  Deviates from the prescribed `flutter_map_marker_cluster` package —
  the custom implementation meets the V2 §6 acceptance criteria without
  introducing a new pub dependency. FIX_PLAN §9.3 checkbox is now ☑.
- S6-T6 (S4-T10) — Map tab ↔ activity map bidirectional integration.
  `ActivityDetailPage` gains `initialTabIndex` parameter;
  `MapPage._meetingMarker` passes `initialTabIndex: 2` so tapping a
  meeting pin on the Map tab opens the activity directly on its Route
  sub-tab. `MapPage` gains `initialEventId` constructor parameter;
  `ActivityMenuSheet` gains a seventh action `onShowOnMap` that pushes
  `MapPage(initialEventId: event.id)` as a full-screen route centred on
  the activity's first route. Two sub-steps deferred to a future sprint
  (bottom-nav tab switch requires lifting MainScaffold state;
  participant popup swipe-up -> UserProfilePage pending route
  finalization). See ADR-006 for details.
- S6-T7 (S3-T13) — Chat menu with 7 items. Already implemented in
  `activity_chat_tab.dart` (`chatMenuItems` + `onChatMenu` hosting
  Search / Media / Pinned / Shared routes / Files / Mute / Export via a
  `PopupMenuButton` in `activity_detail_page.dart`'s SliverAppBar).
  Minor follow-ups noted: persist Mute flag to `GroupMember.muted`
  (currently in-memory); align "Files" label with spec wording
  "Shared files" if strict adherence is desired. FIX_PLAN §9.3 checkbox
  is now ☑.
- Stale PRs #2, #3, #4 closed without merge; their respective branches
  deleted from origin.

Reference

FIX_PLAN.md §9.3 (P2 checklist), §9.4 (verify commands)

adr/ADR-006-Sprint-6-Release-Hardening.md

AGENTS.md (one PR per task; CI must be green before merge)

---

## 2026-09-07

### V3.0.3 — Three user-reported bugs fixed

Status

Accepted

Description

Three regressions reported after testing the V3.0.2 build (workflow run
#34046041610):

1. **Chat does not work between devices (critical).** User 1 scans
   User 2's group QR, the group / activity / participants appear on
   User 1, but messages sent by User 1 in the activity chat do not
   show at User 2. Root cause: the registered `LocalCommunicationService`
   was an in-process loopback only — no bytes ever left the sender.
2. **Reverse QR scan does nothing.** User 2 scanning User 1's group QR
   produced no visible feedback. The page relied on
   `MobileScanner` auto-starting its internal controller; permission
   failures and lifecycle pauses left the camera silently stopped.
3. **Map icon in CreateActivity does nothing.** Tapping the map icon
   in the "Meeting point" field silently set the coordinates to the
   user's current GPS (or a Kyiv fallback) without ever opening a map.

Decisions

- ADR-008 — Local-network UDP transport for chat. Introduces
  `LocalNetworkCommunicationService` as a decorator around
  `LocalCommunicationService`. Chat envelopes are JSON-encoded and
  broadcast to `255.255.255.255:53100`. `MessageRepository.sendText` /
  `sendAttachment` now invoke `_broadcast` after the local save, and a
  new `ingestIncoming` method performs an idempotent upsert on the
  receiving side. The Android side acquires `WifiManager.MulticastLock`
  via a new `pokatuha/network` MethodChannel so the Wi-Fi chip keeps
  delivering broadcast packets to the app. New permissions:
  `ACCESS_WIFI_STATE`, `ACCESS_NETWORK_STATE`,
  `CHANGE_WIFI_MULTICAST_STATE`. In-process loopback stays untouched so
  unit tests stay deterministic; the transport is injectable as an
  optional `CommunicationService?` constructor parameter on
  `MessageRepository` (null in tests).
- QrScannerPage rewritten with an explicit `MobileScannerController`
  (`autoStart: false`), an explicit `_start()` request that surfaces
  camera permission state, and a "Scan" / "Stop" button at the bottom
  that toggles scanning. The page also observes `AppLifecycleState` so
  the camera is restarted when the app returns to the foreground (root
  cause of the "nothing happens" reverse-direction bug — the camera was
  left stopped after the permission dialog paused the activity). A
  status banner shows "Scanning…" / "Stopped" / "Camera permission
  denied" so the user is never left guessing.
- New `MapPickerPage` (`lib/presentation/map/map_picker_page.dart`)
  opens from the "Meeting point" map icon. Uses `flutter_map` (already
  a dependency) + a new `GeocodingService` that wraps the
  OpenStreetMap Nominatim API (no API key, free, Local-First compliant —
  see ADR-007 implicit). The page supports:
  - free-text address search (debounced 700ms, max 1 req/sec per
    Nominatim policy),
  - tap on the map → reverse-geocode → set the marker + address label,
  - "Find me" FAB → centres the map on the current GPS,
  - "Confirm" → returns a `MapPickerResult{lat, lng, label}` to the
    caller.
  The selected address is written into the meeting-point text field
  and the lat/lng are stored internally as before.
- Added 14 new tests (geocoding service round-trip with a MockClient;
  `MessageRepository.ingestIncoming` happy path + idempotency +
  hostile payload rejection; `UserRepository.upsertStub` happy path +
  no-clobber + empty-displayName fallback).
- Localization: added 14 new strings in `app_en.arb` + `app_ru.arb`
  (scan/stop, scanning, camera permission denied, scan failed,
  map picker title/hint/search hint/resolving, find me, confirm,
  location unavailable, pick on map, meeting point hint, P2P notice).

Verification

- `flutter analyze` — 0 new issues (4 pre-existing info-level warnings
  unchanged).
- `flutter test` — 146 / 146 passing (was 132, +14 new tests).

Reference

adr/ADR-008-Local-Network-UDP-Transport.md

---

End of document.
