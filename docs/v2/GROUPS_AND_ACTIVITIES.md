# Pokatuha V2 — Groups and Activities

Status: APPROVED
Depends on: ARCHITECTURE_V2.md

---

## 1. Group-first model

The application is organized around permanent groups.

Users do not create standalone activities from the main screen.

Flow:

Home → Group → Activity → Activity Chat

---

## 2. Group types

### Public

- discoverable by nickname / link / QR
- visible in search
- join without approval (optional)

### Private

- not discoverable
- join by invitation only

### Invite-only

- discoverable optionally
- requires approval from admin

---

## 3. Group creation

Fields:

- group name
- avatar
- description
- type
- default map
- default activity color (optional)

---

## 4. Group permissions

### Owner

- delete group
- transfer ownership
- manage admins

### Admin

- create activities
- invite/remove members
- pin messages
- manage polls

### Member

- participate
- create polls (configurable)
- upload routes/files

---

## 5. Group screen

### Top bar

- group avatar
- group name
- search
- menu

### Tabs

- Activities
- Members
- Media
- Settings (admins only)

---

## 6. FAB behavior

Inside group:

Primary action: Add Activity

No additional actions are shown in the FAB unless approved later.

---

## 7. Activity list

Activities are displayed as colored glass cards.

### Status colors

- Purple: planned
- Blue: active
- Green: started
- Orange: finished
- Red: cancelled

Actual colors come from design_tokens.md.

---

## 8. Activity card content

- mini route map
- title
- date and time
- distance
- duration
- average speed
- participant count
- weather summary
- action buttons

---

## 9. Activity menu

Three-dot menu must contain:

- Edit
- Duplicate
- Share
- Pin in group
- Archive
- Delete

---

## 10. Activity creation

Fields:

- title
- description
- date
- start time
- meeting point
- route file
- activity color
- share live location
- weather preview

---

## 11. Activity color propagation

Selected color is applied to:

- activity card
- internal surfaces
- chips
- buttons
- map rings
- poll accents
- route accents

---

## 12. Activity tabs

Exactly four tabs:

- Main
- Chat
- Polls
- Route

Do not add Photos, Weather or Statistics tabs.

---

## 13. Main tab

Contains glass blocks:

### Weather block

- temperature
- condition
- wind
- precipitation

### Route block

- distance
- elevation
- estimated duration

### Participants block

- avatars
- live sharing count

### Actions block

- Open map
- Share activity

---

## 14. Chat lifecycle

Each activity has an independent chat.

### When activity is active

- full messaging
- reactions
- replies
- attachments
- voice messages

### When activity is closed

- read-only forever
- searchable
- media preserved
- polls preserved

---

## 15. Multiple active activities

A group may contain multiple active activities simultaneously.

Each has:

- separate chat
- separate route
- separate polls
- separate live map

---

## 16. Polls

Inside activity only.

Supported:

- single choice
- multiple choice
- anonymous
- public
- close poll
- view results

---

## 17. Route tab

Supports:

- import GPX
- import FIT
- import KML
- preview
- download
- share
- navigation handoff

---

## 18. Archive

Finished activities move to Archive.

Archive keeps:

- chat
- route
- weather snapshot
- statistics
- media
- polls

Nothing is deleted automatically.

---

## 19. Search

Group activity search supports:

- title
- date
- distance
- status
- color
- participants

---

## 20. UI constraints

Use components only from:

- UI Kit
- design_tokens.md

Do not invent new button styles, shadows or chip styles.
