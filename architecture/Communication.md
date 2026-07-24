# Communication Architecture

Version: 1.0.0

Status: APPROVED

---

# Purpose

Define how devices exchange information.

---

# Communication Modes

Pokatuha supports three communication modes.

1.

Live Mode

2.

Sleep Mode

3.

Offline Mode

---

# Live Mode

Used during active rides.

Transport

WebRTC

Connection

Peer-to-Peer

Realtime synchronization

Objects

GPS

Chat

Polls

Ride Stages

Presence

Arrival Events

---

# Sleep Mode

Application inactive.

Wake mechanism

Firebase Cloud Messaging

Flow

```
Ride Update

↓

FCM Push

↓

Application Wake-Up

↓

Reconnect WebRTC

↓

Synchronize
```

FCM never transports user data.

---

# Offline Mode

Internet unavailable.

Application continues working locally.

Queue

Messages

Votes

GPS

Archive

Photos

Synchronization begins automatically after internet returns.

---

# Arrival Detection

Every participant periodically sends location while Live Mode is active.

If distance to Meeting Point becomes less than configured threshold

↓

Generate Event

↓

Notify participants

Examples

Alex is 500 m away

John is arriving

Maria has arrived

Thresholds should be configurable.

---

# Battery Optimization

Reduce GPS frequency while stationary.

Suspend unnecessary synchronization.

Reconnect only when needed.

---

# Security

Encrypt signaling where applicable.

Validate peers.

Reject invalid sessions.

Never expose private identifiers.

---

End of document.