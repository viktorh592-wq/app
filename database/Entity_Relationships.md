# Entity Relationships

Version: 1.0.0

Status: APPROVED

---

# Overview

This document describes logical relationships between entities.

---

User

↓

creates

↓

Event

---

Event

↓

contains

↓

Participants

Messages

Polls

Routes

Media

Statistics

Archive

---

Participant

↓

belongs to

↓

Event

and

User

---

Message

↓

belongs to

↓

Event

↓

created by

↓

Participant

---

Poll

↓

belongs to

↓

Event

↓

contains

↓

Votes

---

Vote

↓

belongs to

↓

Participant

↓

and

↓

Poll

---

Route

↓

belongs to

↓

Event

↓

contains

↓

Waypoints

↓

contains

↓

TrackPoints

---

Archive

↓

references

↓

Completed Event

↓

contains

↓

Messages

Media

Statistics

Timeline

Votes

GPX

---

Notification

↓

belongs to

↓

User

and

Event

---

Theme

↓

belongs to

↓

User

---

Settings

↓

belongs to

↓

User

---

Future Modules

Bike

↓

belongs to

↓

User

---

Equipment

↓

belongs to

↓

Bike

---

Maintenance

↓

belongs to

↓

Bike

---

End of document.