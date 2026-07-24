# Entity Versioning

Version: 1.0.0

Status: APPROVED

---

# Purpose

Track modifications of local entities.

---

# Rules

Initial version = 1

Each successful modification increments version.

Version numbers never decrease.

---

# Conflict Resolution

If synchronization detects different versions:

Higher version wins only when timestamps confirm newer data.

Future conflict resolution strategies may be added.

---

End of document.