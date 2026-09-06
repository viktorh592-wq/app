# ADR-008: Local-Network UDP Transport for Chat

- **Status:** Accepted
- **Date:** 2026-09-07
- **Context:** V3.0.4 — user-reported bug 1 (chat messages do not reach the
  other device after a QR join).
- **Supersedes:** none. Related: ADR-002 (WebRTC), ADR-003 (FCM wake-up only),
  ADR-005 (storage), ADR-006 (dependency hygiene).

## Context

The app is Local-First (ADR-001): every device keeps its own Sembast store and
no central server transports user data. The chat, however, was wired to
`LocalCommunicationService`, whose `broadcast()` routed the envelope back to
the **same device** (in-process loopback). Messages were persisted locally and
displayed, but they never left the phone — so after scanning a group QR code
the joiner saw the group, the activities and the members, yet the two devices
could not actually exchange chat messages.

The architecture reserved Live Mode for WebRTC (ADR-002), but WebRTC requires
a signaling exchange plus TURN infrastructure for reliability — a separate
sprint. Meanwhile the dominant real-world scenario reported by users is:
**both users are physically together and on the same Wi-Fi / hotspot** (they
just scanned each other's QR code).

## Decision

Add a real transport — `LocalNetworkCommunicationService` — that layers UDP
broadcast on the local network on top of the existing loopback behaviour:

1. **Transport.** Every device binds `0.0.0.0:53100` (fixed port) and both
   listens and broadcasts there. No discovery protocol, no addresses to
   configure: peers on the same L2 segment see each other automatically.
   Datagrams target the limited broadcast `255.255.255.255` plus the
   directed broadcast of each private IPv4 interface (`192.168.x.255`,
   `10.x.x.255`, `172.16–31.x.255`).

2. **Envelope format.** JSON, versioned (`v:1`), with a random envelope id
   (`eid`) and a random per-process `origin`. Receivers drop duplicates by
   `eid` (bounded set of 1024 ids) and drop their own envelopes by `origin`
   — this makes echo loops impossible without pairing logic.

3. **Android specifics.** `WifiManager.MulticastLock` is acquired through a
   `pokatuha/network` MethodChannel so the Wi-Fi chip keeps delivering
   broadcast datagrams to the foreground app (required on most devices);
   the manifest gains `CHANGE_WIFI_MULTICAST_STATE`, `ACCESS_WIFI_STATE`,
   `ACCESS_NETWORK_STATE`.

4. **Chat flow.** `MessageRepository` broadcasts every locally-sent message
   (`chat` envelope). `ChatSyncService` persists incoming `chat` envelopes
   (idempotent by message id + version) and acknowledges them (`chatAck`);
   the sender flips its bubble to `delivered` on ack. Ingest paths never
   re-broadcast, so no message storms are possible.

5. **History sync.** After a group is materialised / re-opened through a QR
   invite, the device broadcasts a `chatHistoryRequest` (rate-limited to one
   per 5 s per group). Members answer with one `chatHistoryBatch` datagram
   per event (last 50 messages). Requests are answered only for requesters
   that are members of the group on the answering device (courtesy filter).

## Consequences

- **+** Chat works today, on the target scenario (same Wi-Fi / hotspot),
  with zero new pub dependencies and zero server infrastructure.
- **+** Local-first semantics untouched: the local store stays the source of
  truth; the transport is best-effort and failure-tolerant.
- **−** UDP is unreliable by nature. Mitigations: acks for live messages,
  history resync on every QR scan heals missed messages. Delivery state is
  best-effort: no ack → bubble stays `sending`, history sync still delivers
  the content.
- **−** Only devices on the same network segment can talk. Cross-network
  chat remains a WebRTC (ADR-002) work item; the `CommunicationService`
  interface is unchanged, so the transport can be swapped later without
  touching business modules.
- **−** LAN UDP is unauthenticated. The history endpoint answers only
  members (best-effort privacy filter); no secrets ever transit the wire —
  payloads are the same activity/group data that QR payloads already carry.
- **−** App-capability limitations: with **AP/client isolation** enabled on
  the router, broadcast packets are dropped — chat between the two devices
  will not flow until isolation is disabled. Documented in the README
  troubleshooting section.

## Verification

- `test/database/message_repository_test.dart` — broadcast on send, idempotent
  ingest, version guard, recentByEvent window.
- `test/domain/chat_sync_service_test.dart` — full loop between two fake
  devices: live delivery, ack, history request → batch → ingest.
- `test/domain/local_network_communication_service_test.dart` — envelope
  codec roundtrip, duplicate/self filtering (network boot disabled in tests).
