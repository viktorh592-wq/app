# ADR-003

Title

Firebase Cloud Messaging for Wake-Up Notifications

Status

APPROVED

Date

2026-07-24

---

# Context

Mobile operating systems suspend background applications to save battery.

Pokatuha requires a mechanism to wake the application when new ride events occur.

---

# Decision

Use Firebase Cloud Messaging exclusively for wake-up notifications.

FCM must not transport chat history, GPS tracks, media or archive data.

---

# Alternatives Considered

Persistent background service

Rejected due to battery impact and platform restrictions.

Custom push infrastructure

Rejected due to operational complexity.

---

# Consequences

Positive

- Free to use
- Reliable delivery
- Minimal maintenance

Negative

- Dependency on Google Play Services for Android devices that include them

---

# AI Guidance

Only integrate `firebase_core` and `firebase_messaging`.

Do not introduce other Firebase services unless explicitly approved.

---

End of document.