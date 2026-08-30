[README.md](https://github.com/user-attachments/files/30339029/README.md)
# app# Pokatuha

> Private P2P activity platform for cyclists, hikers, runners and outdoor communities.

---

# Status

Version: 3.0.0

Status: Approved — V3.0.0 release-hardened (Sprint 6)

Project Type: AI-Ready Documentation

---

# Project Vision

Pokatuha is a privacy-first platform designed for organizing group outdoor activities.

Unlike existing applications, Pokatuha does not rely on a centralized backend for storing user data.

All personal data belongs to the user.

---

# Main Principles

✔ Local-first

✔ Privacy-first

✔ Offline-first

✔ P2P communication

✔ Modular architecture

✔ AI-ready documentation

✔ No mandatory cloud

---

# Core Features

- Activity creation
- Group management
- Live GPS
- Route planning
- Chat
- Polls
- Archive
- GPX
- Weather
- Notifications
- Photo sharing
- Video sharing
- Event stages
- Custom activity types

---

# Supported Activities

Default:

- MTB
- XC
- Enduro
- Downhill
- Gravel
- Road
- BMX
- E-Bike
- Hiking
- Running

Users may create unlimited custom activity types.

---

# Core Architecture

## Storage

Local only.

Recommended database:

Isar

Stored locally:

- Chat
- Photos
- Videos
- GPX
- Events
- Archive
- Settings
- Votes

---

## Communication

Two communication modes.

### Live Mode

WebRTC

↓

Peer-to-Peer

↓

GPS

↓

Chat

↓

Events

No cloud storage.

---

### Sleep Mode

Firebase Cloud Messaging

↓

Wake application

↓

Reconnect WebRTC

↓

Continue synchronization

FCM is used ONLY for wake-up notifications.

FCM is NEVER used for:

- storage
- chat
- history
- cloud synchronization

---

# Maps

Default:

- OpenStreetMap
- MapLibre

Optional:

- Google Maps
- HERE
- 2GIS
- Yandex Maps

User selects preferred provider.

---

# Weather

Provider

Open-Meteo

Requirements

- Free
- No API key
- No payment

---

# Notifications

Push notifications

Android

Firebase Cloud Messaging

Only wake-up notifications.

---

# Privacy

The application never stores user data on developer-owned servers.

User controls:

- GPS sharing
- Photo sharing
- Event visibility
- Profile visibility

---

# Repository Structure

```
docs/              V2 spec (docs/v2/*), Decision_Log, ADR index
architecture/      V1 architecture reference (Architecture.md)
adr/               Architectural Decision Records (ADR-001..006)
prompts/           AI prompts (MasterPrompt, etc.)
schemas/           JSON / data schemas
diagrams/          Diagrams
assets/            Icons, fonts (Inter), images
lib/               Flutter application source
  core/            utils, constants, errors, extensions
  database/        Sembast collections + DatabaseService (ADR-005)
  domain/          enums, repositories, services (business layer)
  presentation/    theme, widgets, 5-tab navigation + feature screens
  l10n/            generated localizations (en, ru)
  main.dart / app.dart
android/           Android config + permissions + FCM wake-up service
test/              unit tests (utils, GPX, repositories, event service)
.github/workflows/ CI: flutter.yml (analyze+test), build-apk.yml (release APK)
```

---

# Documentation

This repository contains the complete AI-ready documentation for the Pokatuha platform.

The documentation is intended for:

- Claude Code
- Cursor
- ChatGPT
- Gemini
- GitHub Copilot

---

# License

TBD

---

# Current Documentation Progress

| Document | Status |
|----------|--------|
| README | ✅ |
| AI_RULES | ✅ |
| Vision | ✅ |
| MasterPrompt | ✅ |
| SRS | ✅ |
| UI Bible | ✅ |
| Database | ✅ |
| REST API | n/a (P2P, no REST backend) |
| WebSocket API | n/a (WebRTC P2P) |
| Architecture | ✅ |

---

# Implementation

The Flutter application is implemented under `lib/` following the documented
layered, modular architecture (Architecture.md):

```
lib/
  core/            utils, constants, errors, extensions
  database/        Sembast collections + DatabaseService (ADR-005)
  domain/          enums, repositories, services (business layer)
  presentation/    theme, widgets, 5-tab navigation + feature screens
  l10n/            generated localizations (en, ru)
  main.dart / app.dart
android/           Android config + permissions + FCM wake-up service
test/              unit tests (utils, GPX, repositories, event service)
```

## Storage note

ADR-004 specified Isar. Isar v3's code generator is incompatible with the
required Dart 3.8 toolchain (unmaintained; v4 is dev-only), so the storage
engine is Sembast (ADR-005). The Local-First architecture, privacy rules and
all entity standards (UUID v7, UTC timestamps, versioning, soft delete) are
preserved unchanged.

## Build & Run

```bash
flutter pub get
flutter run
```

No code generation step is required (Sembast is pure-Dart).

## Verify

```bash
flutter analyze   # static analysis (0 issues)
flutter test      # unit tests
```

CI runs both checks on every push (`flutter.yml`) plus a release APK
build (`build-apk.yml`) on pushes to `main`. Both must be green before
merge.

## Localization

Generate localization files after editing `l10n/*.arb`:

```bash
flutter gen-l10n
```

The generated `lib/l10n/app_localizations*.dart` files are committed
per `l10n.yaml`'s `output-dir: lib/l10n` convention so the project
builds without a `gen-l10n` step on the CI runner.

---

# Sprint status (V3.0.0)

| Sprint | Scope | Status |
|--------|-------|--------|
| 1 | Groups, Invite/QR, Map FAB (P0) | merged (PR #8) |
| 2 | Design system, activity menu, accent color (P0/P1) | merged (PR #9) |
| 3 | Telegram-style chat (P1) | merged (PR #10) |
| 4 | Map layers, Live GPS, clustering (P1/P2) | merged (PR #11) |
| 5 | Polls, routes, chat cards (P2) | merged (PR #12) |
| 6 | CI stabilization, dead code, Map↔activity integration, docs (release hardening) | this PR |

See `docs/Decision_Log.md` for per-sprint acceptance records and
`adr/ADR-006-Sprint-6-Release-Hardening.md` for the Sprint 6
architectural decisions.

---

End of document.
