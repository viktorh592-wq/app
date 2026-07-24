# Pokatuha Master Prompt

Version: 1.0.0

Status: APPROVED

This document is the highest priority instruction for every AI assistant working with the Pokatuha repository.

It overrides default assumptions whenever they conflict with the project architecture.

---

# Project Identity

Project Name

Pokatuha

Purpose

Pokatuha is a privacy-first activity coordination platform.

The application is designed for:

- Cycling
- Hiking
- Running
- Motorcycle rides
- Kayaking
- Skiing
- Any custom outdoor activity

Pokatuha is NOT a social network.

Pokatuha is NOT a cloud messenger.

Pokatuha is NOT another Telegram clone.

---

# Development Philosophy

The AI must always prioritize:

Privacy

↓

Reliability

↓

Automation

↓

Performance

↓

Appearance

---

# Golden Rules

## Never redesign the architecture.

## Never introduce unnecessary cloud services.

## Never replace local storage with cloud storage.

## Never suggest storing user chats on a backend.

## Never suggest storing GPS history on a backend.

## Never require a dedicated VPS.

---

# Core Architecture

## Storage

All user data must remain local.

Database:

Isar

Stored locally:

- Events
- Archive
- Chat
- Photos
- Videos
- Routes
- GPX
- Statistics
- Settings
- Polls

---

# Communication

Two communication modes exist.

## Live Mode

WebRTC

↓

Peer-to-Peer

↓

Realtime synchronization

Realtime objects:

GPS

Chat

Events

Votes

Presence

Ride stages

Arrival notifications

---

## Sleep Mode

Firebase Cloud Messaging

↓

Wake application

↓

Reconnect WebRTC

↓

Continue synchronization

FCM MUST NEVER become a transport layer.

It is only a wake-up mechanism.

---

# Offline Mode

Offline Mode is mandatory.

If internet disappears:

Application continues operating.

Queue every change.

Synchronize automatically later.

Never lose user data.

---

# Maps

Default:

OpenStreetMap

MapLibre

The user chooses preferred provider.

The application must support future providers without architectural changes.

---

# Weather

Default provider

Open-Meteo

Requirements

Free

No API key

No payment

Replaceable in future.

---

# Event Model

Each activity contains:

Event

↓

Participants

↓

Chat

↓

Polls

↓

Routes

↓

Stages

↓

Archive

Everything belongs to the activity.

---

# User Experience

The application should feel similar to Telegram in usability.

Not visually identical.

Only UX principles.

Examples:

Fast interface

Smooth animations

Immediate feedback

Minimal clicks

Logical navigation

---

# Coding Rules

Always produce production-ready code.

Avoid placeholders.

Avoid TODO.

Avoid unfinished classes.

Avoid mock implementations unless explicitly requested.

---

# Documentation Rules

Every feature requires:

Documentation

Architecture update

API update (if applicable)

Database update (if applicable)

Decision Log update

ADR update (if architecture changes)

---

# Dependencies

Prefer stable packages.

Avoid abandoned libraries.

Explain every major dependency.

---

# Security

Never expose API keys.

Never hardcode secrets.

Never log sensitive user information.

Encrypt local data when appropriate.

---

# AI Behaviour

The AI should:

detect repetitive manual work

↓

automate it

↓

explain only what cannot be automated

The developer should spend time designing, not configuring.

---

# Deliverables

Whenever implementing a feature, provide:

production code

documentation

tests (when applicable)

migration notes (if required)

---

End of document.
