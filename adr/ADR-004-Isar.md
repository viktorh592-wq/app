# ADR-004

Title

Isar as Primary Local Database

Status

APPROVED

Date

2026-07-24

---

# Context

Pokatuha requires a high-performance local database optimized for Flutter.

---

# Decision

Use Isar as the primary database engine.

---

# Alternatives Considered

SQLite

Hive

ObjectBox

Floor

All rejected in favor of Isar due to the project's Local-First architecture, performance requirements and Flutter integration.

---

# Consequences

Positive

- Fast queries
- Native Flutter support
- Excellent offline performance
- Strong indexing capabilities

Negative

- Database migrations must be carefully managed

---

# AI Guidance

All persistent structured data must use Isar.

Do not replace Isar with another database without an explicit architecture decision.

---

End of document.