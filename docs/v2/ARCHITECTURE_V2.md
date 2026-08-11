# Pokatuha V2 — Final Architecture

Status: APPROVED
Source of truth: Figma + UI Kit + user review
Target: Flutter (Android first)

---

## 1. Product vision

Pokatuha is a privacy-first, local-first activity coordination platform for cyclists, hikers and outdoor groups.

The application combines:

- Telegram-style UI/UX
- Session-style privacy
- P2P messaging
- Local-only message storage
- Minimal infrastructure (FCM wake-up only)

---

## 2. Core architecture

Group → Activities → Activity Chat

Each activity has its own:

- chat
- route
- weather block
- polls
- participants
- live map

When an activity is closed:

- chat becomes read-only forever
- route remains available
- photos remain available
- statistics remain available

---

## 3. Network model

P2P + FCM wake-up + gossip store-and-forward

### Principles

- No central chat server
- Messages are never stored on the server
- FCM contains no message content
- Devices relay messages for offline participants
- Maximum 30 participants per group

---

## 4. Message flow

1. Sender creates message
2. Message is encrypted locally
3. Stored in local outbox
4. FCM wake-up sent to group participants
5. Online peers connect via WebRTC
6. Message delivered
7. Receiving peer becomes relay
8. Offline peers sync later from any online peer

---

## 5. Storage

### Local only

- messages
- photos
- videos
- routes
- polls
- activity data
- theme settings

### Minimal relay data

- public user id
- public key
- FCM token
- group membership

---

## 6. Navigation

Bottom navigation:

- Groups
- Map
- FAB
- Archive
- Profile

FAB behavior:

### Groups screen

- Add Group

### Inside group

- Add Activity

---

## 7. Activity tabs

Only four tabs are allowed:

- Main
- Chat
- Polls
- Route

Do not add extra tabs.

---

## 8. Main tab content

Contains:

- weather glass card
- route summary card
- participants card
- action buttons

Weather is NOT a separate tab.

Photos are NOT a separate tab.

---

## 9. Activity statuses

### Active

- glass surface
- colored accent

### Started

- glass surface
- stronger colored accent

### Finished

- archive style

All colors and effects must come from the UI Kit.

---

## 10. Activity color propagation

User selects activity color when creating activity.

The color is applied to:

- activity card
- internal headers
- map participant rings
- buttons
- chips
- chat accents
- poll accents

---

## 11. Attachments

Default:

- compress photos
- compress videos

Optional:

- Send without compression

Original file remains local.

---

## 12. History policy

New group members receive only new messages from the moment they join.

No automatic backfill.

---

## 13. Platform target

- Android 13+
- Flutter stable
- Material 3
- Light / Dark / System themes

---

## 14. Source of truth

Figma + UI Kit + approved comments from user review are mandatory.

Do not invent additional screens, chips or buttons outside the approved design.
