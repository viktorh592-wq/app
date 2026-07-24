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

End of document.