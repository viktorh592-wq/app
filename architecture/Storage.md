# Storage Architecture

Version: 1.0.0

Status: APPROVED

---

# Philosophy

User data belong to the user.

Storage is local.

Cloud storage is optional and never mandatory.

---

# Database

Primary

Isar

---

# Local Storage

Stores

Events

Archive

Participants

Messages

Polls

Routes

GPX

Photos

Videos

Statistics

Settings

Activity Types

Custom Categories

---

# File Storage

Large files remain outside database.

Examples

Photos

Videos

GPX

Documents

Database stores metadata only.

---

# Metadata

Photo

Path

Timestamp

Author

Event

Hash

Thumbnail

---

# Encryption

Sensitive data should support local encryption.

Implementation details defined separately.

---

# Backup

Future module.

Local Export

ZIP

Encrypted ZIP

User-selected destination.

---

# Data Ownership

Deleting Pokatuha removes only local application data.

Application never owns user information.

---

End of document.