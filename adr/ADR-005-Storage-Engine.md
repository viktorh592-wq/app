# ADR-005

Title

Local Storage Engine — Sembast

Status

ACCEPTED

Date

2026-07-24

Supersedes

ADR-004 (Isar) — see rationale below

---

# Context

ADR-004 selected Isar as the primary local database.

Isar v3.1.0+1 is the last released stable version (published 2023) and is no
longer maintained. Isar v4 exists only as abandoned dev-previews
(4.0.0-dev.14) and is not production-ready.

On the project's required toolchain (Flutter 3.32 / Dart 3.8) the Isar v3 code
generator cannot run: its `isar_generator` depends on an old `analyzer`/`dart_style`/`source_gen` combination that is mutually incompatible with the
versions required by a Dart 3.8-compatible `build_runner`. Concretely, the
generator fails with `Could not resolve annotation for int isarId` while
processing `@Id()` / `@Index()` annotations, and no consistent set of
`analyzer` / `source_gen` / `dart_style` / `build_resolvers` versions satisfies
both Isar and the modern SDK. Generating the Isar schemas is therefore
impossible on the supported Flutter SDK.

This blocks the entire Local-First data layer, so a working alternative that
preserves every architectural invariant is required.

---

# Decision

Adopt **Sembast** as the local persistence engine.

Sembast is a pure-Dart, file-based, offline-first NoSQL document database with
no native dependencies and no code generation. It runs on every Flutter
target (Android, iOS, desktop, web via `sembast_web`) and on the Dart VM, which
also makes the data layer fully unit-testable in isolation.

All entity standards from the documentation are preserved unchanged:

- UUID v7 identifiers (UUID_Policy.md)
- UTC millisecond timestamps (Timestamp_Policy.md)
- Entity versioning starting at 1 (Versioning.md)
- Soft delete via `isDeleted` / `deletedAt` (Soft_Delete.md)
- The full collection set from Isar_Collections.md
- Indexed lookups (Indexes.md) via Sembast `Filter`s / `Finder` sort orders
- Metadata, `createdBy`/`updatedBy`/`deletedBy`, notes

The collection class names and field names are identical to the originally
documented Isar model, so the business and presentation layers are unaffected.
Entities are serialized to JSON-compatible maps (`toMap` / `applyMap`).

---

# Alternatives Considered

Isar v3

Rejected — generator incompatible with Dart 3.8 (see Context).

Isar v4 (dev previews)

Rejected — not stable, no production release.

Drift (SQLite)

Considered. Excellent and Dart-3 native, but requires code generation and
introduces a relational/SQL model that diverges further from the documented
NoSQL collection model. Kept as a future option if relational queries are
needed.

ObjectBox

Considered. Requires native libs and codegen; heavier than needed for a
Local-First client.

Hive / sembast

Sembast chosen over Hive for richer query/filter/sort support and zero codegen,
while remaining pure-Dart and Local-First.

---

# Consequences

Positive

- Builds and analyzes cleanly on Dart 3.8 / Flutter 3.32
- No code generation step (`flutter pub get` is enough)
- Fully unit-testable in-memory (no platform plugins required)
- Works on all Flutter targets including web
- All Local-First / privacy invariants preserved (ADR-001)

Negative

- Sembast is not as fast as Isar for very large datasets
- No native links/relations; relationships are resolved in the repository layer
- A future migration to Isar (if it is ever maintained again) or Drift would
  require rewriting the storage serialization, but the repository interfaces
  isolate the rest of the app from this

---

# AI Guidance

The Local-First principle (ADR-001) and privacy rules are the real invariants;
the storage engine is an implementation detail. Treat Sembast as the current
local engine.

Never introduce a mandatory cloud database.

If Isar becomes maintained and Dart-3-compatible again, a new ADR may revert
the engine; the repository interfaces are designed to make that swap localized.

Do not add code-generation dependencies back for the storage layer unless the
chosen engine requires them and they work on the supported SDK.

---

End of document.
