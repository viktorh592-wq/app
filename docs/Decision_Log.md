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

## 2026-09-01

### V3.0.1 — User-feedback bug fixes

Status

Accepted

Branch

`fix/user-feedback-bugs-v3.0.1`

Description

Four bugs reported by a v3.0.0 user during real-device testing were
fixed in a single PR. Each fix is isolated to its layer (presentation /
domain / data) and keeps the Local-First / Privacy-First invariants
intact — no new pub dependencies, no cloud calls, no architectural
redesign.

Bug 1 — «Участник не найден» when inviting a user by their personal QR

Cause

`DeepLinkDispatcher.handle` and the group invite flow called
`UserRepository.findByPublicId`, which only returns users already known
on the device. In a server-less, P2P-not-yet-shipped app the scanned
user is almost always unknown locally, so every scan rejected the
invite with the localized «Участник не найден» toast.

Fix

- `UserRepository.getOrCreateStubFromPublicId(String publicId)` —
  idempotent creation of a stub `UserCollection` whose `id` equals the
  12-char public id (stable so subsequent scans of the same QR return
  the same record instead of creating duplicates).
- `GroupService.inviteByPublicId(...)` — looks the user up via
  `getOrCreateStubFromPublicId`, then calls the existing
  `inviteMember` (re-uses the 30-member cap and duplicate guards).
  `GroupService`'s constructor gets an optional `UserRepository`
  parameter so existing tests keep passing.
- New invite-sheet entry «Сканировать QR участника» on the group
  members tab opens `QrScannerPage` and routes a parsed
  `pokatuha://u/<ID>` link through `GroupService.inviteByPublicId`.
- `DeepLinkDispatcher` no longer bails out on an unknown user — it
  creates a stub and opens the (mostly empty) profile page so the
  user can still interact (add to contacts, invite to another
  group, etc.).

Tests

`test/database/user_repository_test.dart` — six new tests for
`getOrCreateStubFromPublicId` (creation, idempotency, case
normalization, empty rejection, lookup by public id, nickname-search
visibility).

`test/domain/group_service_test.dart` — four new tests for
`inviteByPublicId` (stub creation + membership, record reuse,
duplicate rejection, no-UserRepository wiring rejection).

Bug 2 — File picker can't select a GPX/KML file from phone storage

Cause

`activity_route_tab.dart` used `FilePicker.platform.pickFiles(type:
FileType.custom, allowedExtensions: ['gpx','kml','fit'])`. Android's
Storage Access Framework picker filters by MIME type when an explicit
extension list is passed, and `.gpx` / `.kml` typically have no
registered MIME entry on the device — the file appears greyed out or
silently does nothing when tapped.

Fix

Changed to `type: FileType.any` so the picker shows every file SAF
exposes, then validate the extension ourselves after the pick. `.fit`
is still detected and rejected with the existing localized
`fitNotSupported` message; unsupported extensions get
`unsupportedFormat`. Falls back to parsing the file name when the
picker does not populate `PlatformFile.extension` (some SAF sources
return null for it).

Tests

No new test added — the picker is an OS-level integration that
cannot be unit-tested without mocking `FilePicker.channel`. The
fallback parsing path is covered by code inspection; the change is
small enough to be visually reviewable.

Bug 3 — Map page: missing zoom + my-location buttons, only 2 of 5
providers render

Cause

Two separate root causes:

1. `MapService._urlTemplate` used `{a-c}` and `{a-d}` placeholders for
   the subdomain rotation. `flutter_map` 7.x only expands the `{s}`
   placeholder (with the `subdomains` parameter); `{a-c}` etc. are
   passed literally to the tile server, producing 404s. Result: only
   OSM (no subdomain) and Esri (single origin) rendered — CyclOSM,
   OpenTopoMap and Carto Voyager were silently broken.
2. The Map page had no zoom in/out buttons or "my location" button.
   `flutter_map` does not include these by default; they need to be
   added as overlay widgets.

Fix

- `MapService._tileConfig(p)` returns a `_TileConfig(urlTemplate,
  subdomains)` pair per provider; `tileLayer()` passes both to the
  `TileLayer` widget. CyclOSM and OpenTopoMap use `['a','b','c']`,
  Carto Voyager uses `['a','b','c','d']`, the rest use an empty list.
- `urlTemplateFor(p)` and a new `subdomainsFor(p)` are exposed for
  tests.
- `MapPage` now wraps `FlutterMap` in a `Stack` with a `Positioned`
  column on the right edge containing three `_MapOverlayButton`s:
  zoom in (+), zoom out (−) and «Find me» (my location). The existing
  bottom-right FAB still opens the action sheet with the full menu
  (share location, route, GPX, layer switcher, participants list).
- `_zoomIn` / `_zoomOut` use `MapController.camera.center` + a 1.0
  zoom step, clamped to the [3, 19] range declared in `MapOptions`.
- `_MapOverlayButton` — white rounded square with shadow + dark icon,
  legible on any tile provider.

Tests

`test/domain/map_service_test.dart` — updated URL assertions to
expect `{s}` instead of `{a-c}` / `{a-d}`, and added subdomain-list
assertions (`subdomainsFor`). All five V2 providers are now covered.

Bug 4 — FAB «Add group» / «Add activity» text is clipped

Cause

`app_theme.dart` set `floatingActionButtonTheme.shape = CircleBorder()`
globally, so every `FloatingActionButton.extended` (which is supposed
to use the stadium-shaped pill background for its text label) was
forced into a circular shape and the text label overflowed outside
the background — exactly the user-reported "подложка у текста не под
всем текстом".

Fix

- Removed the global `shape: CircleBorder()` from the FAB theme.
  `FloatingActionButton.extended` now uses the Material 3 default
  stadium shape; plain round FABs (the Map action sheet FAB, the
  `MorphingFab` collapsed state) keep their circular shape via an
  explicit `shape: CircleBorder()` on the widget itself.
- New `MorphingFab` widget (V3.0.1) implements the user-requested UX:
  round "+" first, expands to a labeled pill on the first tap, fires
  the action on the second tap. Auto-collapses after 3.5 s of
  inactivity. Used by `GroupsPage` ("Add group") and
  `GroupDetailPage` ("Add activity").

Tests

No unit tests — `MorphingFab` is a small stateful widget whose
behaviour (tap-to-expand, tap-to-fire) is verified by manual
inspection. The `AnimatedSwitcher` + `setState` pattern is standard.

Verification (cannot be run in this environment — Flutter SDK is not
installed here; the CI workflow `flutter.yml` runs `flutter analyze`
and `flutter test` on push):

- `flutter pub get` — regenerates l10n; `lib/l10n/*` files were
  patched by hand to match the gen-l10n output (added 4 getters
  `scanUserQrToInvite`, `inviteFailed`, `zoomIn`, `zoomOut` in
  `app_localizations.dart`, `app_localizations_ru.dart` and
  `app_localizations_en.dart`).
- `flutter analyze` — expected "No issues found!". Code was written
  against the existing lint set (`prefer_const_constructors`,
  `prefer_const_literals_to_create_immutables`, `strict-casts`,
  `strict-raw-types`).
- `flutter test` — expected all green; the existing test set plus
  the 10 new tests (6 on `UserRepository`, 4 on `GroupService`) plus
  the 5 updated `MapService` URL tests should pass.

Localisation

Four new ARB keys added to both `l10n/app_ru.arb` and
`l10n/app_en.arb`: `scanUserQrToInvite`, `inviteFailed`, `zoomIn`,
`zoomOut`. The corresponding abstract getters and concrete
`@override` implementations were hand-edited in the generated
`lib/l10n/app_localizations*.dart` files because the Flutter SDK
needed for `flutter gen-l10n` is not available in this environment.

Files touched (16)

- `lib/presentation/theme/app_theme.dart`
- `lib/presentation/widgets/morphing_fab.dart` (new)
- `lib/presentation/groups/groups_page.dart`
- `lib/presentation/groups/group_detail_page.dart`
- `lib/domain/services/map_service.dart`
- `lib/presentation/map/map_page.dart`
- `lib/presentation/activities/tabs/activity_route_tab.dart`
- `lib/domain/repositories/user_repository.dart`
- `lib/domain/services/group_service.dart`
- `lib/domain/services/service_locator.dart`
- `lib/presentation/groups/tabs/group_members_tab.dart`
- `lib/presentation/deep_links/deep_link_dispatcher.dart`
- `l10n/app_ru.arb`, `l10n/app_en.arb`
- `lib/l10n/app_localizations.dart`, `lib/l10n/app_localizations_ru.dart`,
  `lib/l10n/app_localizations_en.dart`
- `test/domain/map_service_test.dart`
- `test/domain/group_service_test.dart`
- `test/database/user_repository_test.dart`
- `docs/Decision_Log.md` (this entry)

Reference

ADR-001 (Local-First — no cloud storage introduced)

ADR-005 (Sembast storage — no engine change)

AI_RULES Rule 4 — storage engine unchanged

AGENTS.md — one branch + one PR per logical change; CI must be green
before merge; do not push to `main`

---

End of document.
