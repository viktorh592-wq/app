# Database Overview

Version: 1.0.0

Status: APPROVED

Last Updated: 2026-07-24

---

# Purpose

This document defines the database architecture of Pokatuha.

The application follows a Local-First storage model.

The database exists only on the user's device.

No central database is required.

---

# Database Engine

Primary database

Isar

Reasons

• Extremely fast

• Flutter native

• Offline-first

• Excellent query performance

• Supports indexes

• Supports links

• Cross-platform

---

# Storage Layers

Pokatuha uses three storage layers.

Layer 1

Database (Isar)

Stores structured information.

Examples

Events

Participants

Messages

Polls

Statistics

---

Layer 2

Application Files

Stores

Photos

Videos

GPX

Documents

Map Cache

---

Layer 3

Temporary Cache

Stores

Image thumbnails

Weather cache

Avatar cache

Route previews

Temporary downloads

---

# Data Ownership

Every object belongs to exactly one user device.

Synchronization transfers copies.

Original ownership never changes.

---

# Database Principles

Local First

Offline First

Privacy First

Fast Queries

Minimal Memory Usage

Modular Collections

No SQL

No Server Dependencies

---

# Entity Categories

Core

Event

User

Participant

---

Communication

Message

Reaction

Poll

Vote

Notification

---

Navigation

Route

Waypoint

GPX

TrackPoint

MeetingPoint

---

Media

Photo

Video

Attachment

Thumbnail

---

Statistics

RideStatistics

UserStatistics

Achievement (future)

---

Settings

UserSettings

Theme

MapSettings

NotificationSettings

GPSSettings

PrivacySettings

---

# Relationships

Entity relationships are defined in:

Entity_Relationships.md

---

# Index Strategy

Indexes are defined in:

Indexes.md

---

# Synchronization

Synchronization model:

Sync_Model.md

---

# Encryption

Encryption rules:

Encryption.md

---

End of document.
