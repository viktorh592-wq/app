# Index Strategy

Version: 1.0.0

Status: APPROVED

---

# Purpose

Indexes improve lookup speed.

Avoid unnecessary indexes.

---

# Users

Index

username

email (future)

---

# Events

date

status

activityType

organizerId

---

# Participants

eventId

userId

status

---

# Messages

eventId

createdAt

authorId

---

# Polls

eventId

createdAt

---

# Votes

pollId

participantId

---

# Routes

eventId

---

# Notifications

userId

read

createdAt

---

# Statistics

eventId

userId

---

# Rules

Index only frequently queried fields.

Measure performance before adding new indexes.

---

End of document.