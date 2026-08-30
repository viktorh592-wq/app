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
  `^5.1.2` resolves to) declares `record_platform_interface: ^1.2.0` and
  `record_linux: >=0.5.0 <1.0.0`; pub resolved them to `1.6.0` and
  `0.7.2`, which are mutually incompatible (1.6.0 added a new abstract
  member on `RecordMethodChannelPlatformInterface.hasPermission` that
  `record_linux 0.7.2` does not implement). Fix: pin
  `record_platform_interface: 1.5.0` via `dependency_overrides` (last
  version all federated implementations accept). pubspec.lock updated
  to match.
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

End of document.
