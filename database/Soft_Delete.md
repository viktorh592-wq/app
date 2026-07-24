# Soft Delete

Version: 1.0.0

Status: APPROVED

---

# Purpose

Prevent accidental data loss.

---

# Behaviour

Deleting an entity sets

isDeleted = true

deletedAt = timestamp

---

# Permanent Delete

Only allowed through explicit cleanup procedures.

---

# User Experience

Deleted data disappear from normal UI.

Recovery may be possible before permanent cleanup.

---

# Archive

Archived rides are never soft deleted automatically.

---

End of document.