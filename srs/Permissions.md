# Permissions

Version: 1.0.0

Status: APPROVED

---

# Android Permissions

## Required

Location

Foreground Location

Notifications (Android 13+)

Internet

Network State

Foreground Service

Wake Lock

Vibration

---

# Optional

Camera

Photo Library

Microphone

Bluetooth

Nearby Devices

---

# Permission Rules

Location permission must be requested only when required.

Background location must never be requested automatically.

GPS sharing starts only after explicit user confirmation.

Camera permission is requested only when taking photos.

Microphone permission is requested only for voice messages (future).

Notification permission is requested during onboarding or before the first ride reminder.

If permission is denied, the application must continue working with reduced functionality.

---

# Privacy

The application shall clearly explain why each permission is requested.

Users must be able to revoke permissions at any time.

---

End of document.