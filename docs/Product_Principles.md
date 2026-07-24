# Product Principles

Version: 1.0.0

Status: Approved

---

# Principle 1

Privacy First

Every new feature must answer:

Does this require sending user data to third-party servers?

If yes:

Can it be implemented locally instead?

---

# Principle 2

Offline First

Loss of internet must never destroy user experience.

The application should continue functioning whenever possible.

---

# Principle 3

Local First

Chats

Photos

Routes

Archive

Settings

Statistics

Votes

GPX

All are stored locally.

---

# Principle 4

P2P Before Cloud

Whenever possible:

WebRTC

↓

Peer-to-Peer

↓

Direct synchronization

Cloud services are used only when technically unavoidable.

---

# Principle 5

Automation First

The developer should never perform repetitive configuration manually.

AI assistants must automate configuration whenever possible.

---

# Principle 6

Minimal Dependencies

Avoid unnecessary third-party libraries.

Every dependency increases maintenance cost.

---

# Principle 7

Readable Code

Code should be understandable without comments.

Complex logic must be documented.

---

# Principle 8

Documentation Driven Development

Documentation defines implementation.

Implementation must follow documentation.

---

# Principle 9

User Control

The user decides:

GPS visibility

Profile visibility

Photo sharing

Notification settings

Map provider

Weather provider (future)

Activity type

---

# Principle 10

Scalability

Architecture must support:

2 participants

20 participants

200 participants

without redesign.

---

# Principle 11

Accessibility

The interface must remain usable:

while riding

with gloves

under sunlight

during rain

---

# Principle 12

Modularity

Each feature must be removable without affecting unrelated modules.

---

# Principle 13

No Vendor Lock-In

Pokatuha should not depend entirely on one ecosystem.

Firebase, maps or weather providers should be replaceable.

---

End of document.