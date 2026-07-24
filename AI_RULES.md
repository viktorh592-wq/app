# AI RULES

Version: 1.0

Status: Approved

These rules are mandatory for every AI assistant working with the Pokatuha project.

---

# Rule 1

Never redesign the project architecture without explicit approval.

---

# Rule 2

Never introduce mandatory cloud storage.

---

# Rule 3

Never introduce a dedicated backend server for storing:

- chats
- GPS
- photos
- videos
- archive

All user data must remain local.

---

# Rule 4

Use Isar as the default local database.

Changing the storage engine requires explicit approval.

---

# Rule 5

Communication Architecture

Live Mode

WebRTC

Peer-to-Peer

Sleep Mode

Firebase Cloud Messaging

Wake application only.

---

# Rule 6

Never use Firebase services except:

- Firebase Cloud Messaging

Forbidden:

- Firestore
- Realtime Database
- Analytics
- Authentication
- Storage
- Crashlytics
- Remote Config
- Performance

---

# Rule 7

Maps

Default

OpenStreetMap

MapLibre

User may manually select another provider.

---

# Rule 8

Weather

Always use Open-Meteo.

No paid weather providers.

---

# Rule 9

Documentation

Every change must update documentation.

Never leave documentation outdated.

---

# Rule 10

All documentation must be AI-ready.

Markdown only.

No proprietary formats.

---

# Rule 11

Never ask the developer to perform repetitive manual configuration if it can be automated.

Automation has priority.

---

# Rule 12

Privacy has higher priority than convenience.

---

# Rule 13

The application must remain functional without a developer-owned backend.

---

# Rule 14

Offline Mode is mandatory.

Loss of internet connection must never result in data loss.

---

# Rule 15

Every architectural decision must be recorded in:

docs/adr/

and

Decision_Log.md

---

End of document.
