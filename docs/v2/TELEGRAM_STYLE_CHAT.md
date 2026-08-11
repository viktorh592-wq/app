# Pokatuha V2 — Telegram Style Chat

Status: APPROVED
Depends on: ARCHITECTURE_V2.md

---

## 1. Goal

Implement a Telegram-like chat experience while preserving Session-like privacy and P2P delivery.

The chat must feel familiar to Telegram users.

---

## 2. Supported features

- outgoing / incoming bubbles
- avatars
- reactions
- replies
- forwarded messages
- pinned messages
- voice messages
- photos
- videos
- documents
- location sharing
- read state
- delivery state
- search

---

## 3. Message bubble layout

### Incoming

- avatar visible
- sender name visible in groups
- bubble aligned left

### Outgoing

- no avatar
- bubble aligned right
- delivery state visible

---

## 4. Bubble metrics

Use values from design_tokens.md.

Important:

- max width: 78%
- radius: large
- compact vertical spacing
- Telegram-like grouping

---

## 5. Grouping

Consecutive messages from the same sender within 5 minutes are visually grouped.

Only the last bubble shows the timestamp.

---

## 6. Reactions

Supported reactions:

- 👍
- ❤️
- 🔥
- 😂
- 😮
- 👎
- 🚴
- 📍

Long press opens reaction picker.

---

## 7. Replies

Reply preview shows:

- sender
- short text or attachment type
- colored vertical stripe

Tapping preview scrolls to original message.

---

## 8. Pinned messages

Activity chat supports multiple pinned messages.

Top bar shows:

- latest pin preview
- pin count

Pinned items may be:

- text
- poll
- route
- weather update
- meetup location

---

## 9. Voice messages

Maximum duration: 5 minutes.

### UI

- hold to record
- slide to cancel
- waveform preview
- playback speed 1x / 1.5x / 2x

---

## 10. Photos and videos

Media appears directly in the chat.

No separate Photos tab.

### Sending

Default:

- compressed

Optional:

- Send without compression

---

## 11. Documents

Supported:

- GPX
- FIT
- KML
- PDF
- ZIP
- images
- videos

GPX/FIT/KML show a route preview card.

---

## 12. Delivery states

### Queued

Clock icon

### Sending

Single check animated

### Delivered

Single check

### Synced

Double check

### Decrypted

Shield check in details screen

---

## 13. P2P queue behavior

If nobody is online:

- message stays in local outbox
- marked as Queued

If at least one peer receives it:

- sender may go offline
- peer becomes relay

---

## 14. Search

Search supports:

- text
- sender
- attachments
- polls
- dates

Results open the message position.

---

## 15. Chat menu

- Search
- Media
- Pinned
- Shared routes
- Shared files
- Mute
- Export (local only)

---

## 16. Activity chat header

Shows:

- activity color
- title
- participant count
- live sharing count

The header color follows the activity color.

---

## 17. Attachments row

Bottom sheet contains:

- Camera
- Gallery
- Route
- File
- Location
- Poll
- Voice

No extra attachment types.

---

## 18. Route message card

Route messages display:

- mini map
- distance
- elevation
- duration
- Open button
- Download button

---

## 19. Poll message card

Shows:

- question
- options
- vote counts
- percentage
- close state

---

## 20. Read-only mode

When activity is closed:

- input field hidden
- reactions disabled
- replies disabled
- media still viewable
- search still available

A banner must say:

This activity is archived. Chat is read-only.

---

## 21. Accessibility

- dynamic text
- screen reader labels
- 44dp touch targets
- high contrast in dark mode

---

## 22. Performance

- virtualized list
- lazy media loading
- thumbnail generation
- local cache
- smooth scrolling on 120Hz devices

---

## 23. UI restrictions

Use only components from:

- UI Kit
- design_tokens.md

Do not introduce custom Telegram clones outside the approved design language.
