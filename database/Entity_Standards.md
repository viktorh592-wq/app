# Entity Standards

Version: 1.0.0

Status: APPROVED

---

# Purpose

This document defines the mandatory structure for every database entity.

Every Isar collection must follow these rules.

---

# Mandatory Fields

Every entity shall contain:

id

createdAt

updatedAt

version

isDeleted

---

# Optional Fields

Depending on the entity:

createdBy

updatedBy

deletedAt

deletedBy

notes

metadata

---

# UUID

Use UUID Version 7.

Reason

Chronologically sortable.

Globally unique.

Fast indexing.

---

# Timestamps

All timestamps use UTC.

Never store local time.

Display conversion happens only in the UI.

---

# Versioning

Every entity starts with

version = 1

Each update increments version.

---

# Soft Delete

Deleting an object does not immediately remove it.

Instead

isDeleted = true

deletedAt = timestamp

---

# Metadata

Entities may include a metadata field for future compatibility.

The metadata field must never contain required information.

---

# Validation

Validation occurs before saving.

Required fields must never be null.

---

End of document.