# ADR-008

Title

Local-Network UDP Transport for Chat (V3.0.3 — Bug 1)

Status

ACCEPTED

Date

2026-09-07

---

# Context

User feedback after testing the V3.0.2 build (PR #15 predecessor):

> 1 (critical): chat does not work. User 1 scans the group QR from User 2,
> the group / activity / participants appear on User 1, but messages sent by
> User 1 in the activity chat are NOT displayed at User 2.

Root cause: the previously registered
`LocalCommunicationService` was an in-process loopback only — `broadcast()`
routed the envelope back to the same device's `incoming` stream. No bytes
ever left the sender. As a result, two devices on the same Wi-Fi could each
post messages to their own local store but never saw each other's bubbles.

ADR-002 mandates WebRTC for Live Mode, but WebRTC requires a signaling
exchange (SDP offer/answer + ICE candidates). Building a signaling server
is explicitly forbidden by ADR-001 (Local-First) and AI Rule 3 (no backend
for chat / GPS / photos / videos / archive). The previous sprints deferred
real-time chat to "Sprint 4" without ever landing a transport.

We needed a transport that:

1. Works between two Android devices on the same Wi-Fi (the user's test
   scenario) without a backend.
2. Adds no new pub dependency (AGENTS.md: "No new pub dependencies without
   justification in the PR").
3. Degrades gracefully when the network is unavailable (offline / tests /
   web) so unit tests stay deterministic.
4. Stays compatible with ADR-002 — i.e. is swappable for real WebRTC in a
   future sprint without rewriting the chat UI.

# Decision

Introduce a local-network UDP broadcast transport implemented as a thin
decorator around `LocalCommunicationService`:

```
LocalNetworkCommunicationService implements CommunicationService
  ├── inner: LocalCommunicationService   (in-process loopback — tests + offline)
  └── UDP socket bound to 0.0.0.0:53100  (broadcast + listen on the local Wi-Fi)
```

Chat envelopes are JSON-encoded and broadcast to `255.255.255.255:53100`
(the limited broadcast address — reaches every device on the same L2
segment). Receivers decode the packet, drop their own broadcasts, and emit
the envelope on the shared `incoming` stream. `AppViewModel` subscribes
once at boot and persists incoming messages via
`MessageRepository.ingestIncoming` (idempotent upsert by message id).

The Android side acquires `WifiManager.MulticastLock` via a new
`pokatuha/network` MethodChannel so the Wi-Fi chip keeps delivering
broadcast packets to the app while it is in the foreground. The
`CHANGE_WIFI_MULTICAST_STATE` permission was added to `AndroidManifest.xml`.

`MessageRepository` now takes an optional `transport: CommunicationService?`
constructor parameter. When set, `sendText` / `sendAttachment` invoke
`_broadcast` after the local save — no UI changes required. Tests inject
`null` so the loopback path stays deterministic.

# Consequences

### Positive

- Real-time chat works between two devices on the same Wi-Fi, fully
  Local-First — no cloud, no signaling server.
- Zero new pub dependencies (`dart:io RawDatagramSocket`).
- The transport is hidden behind the existing `CommunicationService`
  interface; swapping it for real WebRTC in a future sprint does not touch
  the chat UI or `MessageRepository`.
- In-process loopback stays untouched, so all 132 pre-existing tests pass
  unchanged.

### Negative

- **Across-network chat does not work.** Two devices on different Wi-Fi
  networks cannot reach each other. This is documented in the chat tab via
  the new `peerToPeerChatNotice` localization string ("Local chat works on
  the same Wi-Fi network between participants").
- **UDP — no delivery guarantee.** Outgoing bubbles move `queued → sending
  → delivered` based on the local simulation in `ActivityChatTab` (S3-T10
  behaviour is preserved). A future sprint should add an ack envelope so
  the bubble reaches `synced` only after the peer confirms.
- **Multicast lock is held while the app runs.** Acquired on first connect,
  released in `MainActivity.onDestroy`. Minor battery impact while the app
  is in the foreground; cleared on background.

### Follow-ups

- Replace UDP with WebRTC data channels once a Local-First signaling
  exchange is available (e.g. QR-coded SDP swap, or a peer-to-peer mDNS
  discovery on the local network). The `CommunicationService` interface
  stays the same.
- Add a delivery ack envelope so outgoing bubbles can transition
  `delivered → synced` based on real peer confirmation.
