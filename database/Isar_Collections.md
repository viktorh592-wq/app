# Isar Collections

Version: 1.0.0

Status: APPROVED

---

# Core Collections

users

events

participants

messages

polls

votes

routes

waypoints

track_points

archives

notifications

photos

videos

attachments

statistics

themes

settings

activity_types

---

# Collection Rules

Every collection

Has UUID

Has createdAt

Has updatedAt

Supports versioning

Supports soft delete when applicable

---

# Naming Convention

camelCase

Class

PascalCase

File

snake_case

Database Collection

snake_case

---

# IDs

Use UUID v7 whenever supported.

Never use incremental IDs.

---

# Timestamps

Always UTC.

Never local time.

Convert to local only in UI.

---

End of document.