# ADR-001

Title

Local-First Architecture

Status

APPROVED

Date

2026-07-24

---

# Context

Most modern applications rely on centralized cloud storage.

This introduces:

- recurring server costs
- privacy concerns
- dependency on backend availability

Pokatuha aims to remain fully functional without mandatory cloud infrastructure.

---

# Decision

Pokatuha adopts a Local-First architecture.

All primary user data are stored on the user's device.

Cloud synchronization is optional and must never be required for core functionality.

---

# Alternatives Considered

Traditional client-server architecture

Rejected.

Reason:

Requires permanent backend.

Cloud-first architecture

Rejected.

Reason:

Violates privacy goals.

---

# Consequences

Positive

- No mandatory backend
- Better privacy
- Offline capability
- Lower operational costs

Negative

- More complex synchronization
- Larger local storage requirements

---

# AI Guidance

Never redesign the project into a server-centric architecture.

Never suggest Firestore, Supabase, PostgreSQL or similar as the primary storage layer.

Always preserve Local-First principles.

---

End of document.