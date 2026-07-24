# Architecture

Version: 1.0.0

Status: APPROVED

Last Updated: 2026-07-24

---

# Overview

Pokatuha is built around a Local-First architecture.

The application is designed to operate independently of a centralized backend.

User data remain under the user's control.

---

# Core Principles

1. Local First
2. Privacy First
3. Offline First
4. Peer-to-Peer Communication
5. Modular Architecture
6. AI-Ready Documentation

---

# High-Level Architecture

```
                           ┌──────────────────────────┐
                           │        User Device       │
                           └────────────┬─────────────┘
                                        │
                    ┌───────────────────┴────────────────────┐
                    │                                        │
            ┌───────▼────────┐                    ┌──────────▼─────────┐
            │ Presentation    │                    │ Background Services │
            │ Flutter UI      │                    │ Notifications       │
            └───────┬────────┘                    └──────────┬─────────┘
                    │                                        │
        ┌───────────▼────────────────────────────────────────▼──────────┐
        │                       Business Logic                          │
        └───────────┬────────────────────────────────────────┬──────────┘
                    │                                        │
          ┌─────────▼────────┐                    ┌──────────▼──────────┐
          │ Local Database   │                    │ Communication Layer │
          │ Isar             │                    │ WebRTC / FCM        │
          └─────────┬────────┘                    └──────────┬──────────┘
                    │                                        │
          ┌─────────▼────────┐                    ┌──────────▼──────────┐
          │ Device Storage   │                    │ External Services   │
          │ Photos / GPX     │                    │ Weather / Maps      │
          └──────────────────┘                    └─────────────────────┘
```

---

# Layers

## Presentation Layer

Responsible for:

- UI
- Navigation
- Themes
- Localization
- Accessibility

Technology

Flutter

---

## Business Layer

Responsible for:

- Ride logic
- Polls
- Notifications
- Archive
- Chat
- GPS
- Weather

Business rules must never depend directly on UI.

---

## Storage Layer

Database

Isar

Stores

- Events
- Users
- Archive
- Polls
- Messages
- Statistics
- Settings

---

## Communication Layer

Contains

Live Mode

Sleep Mode

Offline Mode

---

## Integration Layer

Responsible for external APIs.

Current providers

Weather

Open-Meteo

Maps

OpenStreetMap

MapLibre

---

# Design Goals

High Performance

Low Battery Usage

Minimal Network Usage

No Vendor Lock-In

Scalable

Maintainable

---

# Module Independence

Every module communicates through interfaces.

Modules must never directly depend on each other.

Example

Chat does not know how GPS works.

GPS does not know how Archive works.

Archive receives events only.

---

# Dependency Direction

UI

↓

Business

↓

Repositories

↓

Storage

↓

Platform

Never reverse dependencies.

---

# Future Compatibility

Architecture must support

Desktop

WearOS

Android Auto

Apple CarPlay (future)

Bike Computers (future)

without redesign.

---

End of document.
