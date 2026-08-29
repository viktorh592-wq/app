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

End of document.
