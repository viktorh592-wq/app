# ADR-009: Relay Transport for Cross-Network Chat (Mobile Networks)

**Status:** Accepted (V3.0.5)
**Date:** 2026-09-07
**Relates to:** ADR-001 (Local-First), ADR-002 (WebRTC Live Mode), ADR-003 (FCM wake-up), ADR-008 (Local-Network UDP Transport)

## Context

The V3.0.4 UDP broadcast transport (ADR-008) made chat work between devices
on the same Wi-Fi / hotspot. User testing of build #191 confirmed local
delivery works — and exposed the next gap:

> «нужно доработать, чтоб чат работал и с мобильной сети» — chat must also
> work when devices are on cellular data (different networks).

UDP broadcast is physically confined to one L2 network segment. No amount of
app-side code can carry a UDP datagram across the internet without an
intermediary. Cross-network delivery therefore REQUIRES some third-party
infrastructure — the Local-First principle (ADR-001: "no cloud storage, data
stays on device") has to be balanced against a hard networking constraint.

## Decision

Introduce a **hybrid transport**: `HybridCommunicationService` extends the
ADR-008 UDP transport with an **encrypted relay over MQTT**:

1. **Transport**: `mqtt_client` connecting to a public MQTT broker over TLS
   (`broker.emqx.io:8883` — free, no account, QoS 1). The broker acts purely
   as a datagram pipe; it never stores state beyond in-flight QoS-1 queues.

2. **End-to-end encryption** — the broker is UNTRUSTED. Both peers derive the
   same secret from the group's QR invite material (the invite code and the
   group UUID — both are embedded in every QR invite):
   * `key = SHA-256("pokatuha-relay-v1|gid=<uuid>|code=<CODE>")` (AES-256)
   * `aad = "pokatuha-relay-v1|gid=<uuid>"` (integrity binding to the group)
   * Cipher: AES-GCM-256, random 96-bit nonce per message, 128-bit tag.
   * Wire body: `{v:1, n:<nonce b64url>, c:<ciphertext b64url>, t:<mac b64url>}`

3. **Topic routing**: `topic = "pokatuha/v1/g/" + hex(SHA-256("…topic-v1|<CODE>"))[:20]`.
   Every member of the group derives the same topic from the invite code.

4. **Type allowlist**: only `chat`, `chatAck`, `chatHistoryRequest`,
   `chatHistoryBatch` cross the internet. GPS / presence / arrival traffic
   stays on the LAN — it is high-frequency, meaningless across networks, and
   would waste mobile data and battery.

5. **Local-First compliance**: the relay is best-effort. A message that
   cannot be relayed is still persisted locally and healed by the history
   sync (last 50 messages per event, requested on every join / scan /
   reconnect). The local Sembast store remains the single source of truth;
   the broker holds no user data in readable form.

6. **Background/standby delivery**: the keep-alive task isolate (V3.0.5 bug 1)
   also opens its own relay subscription while the app is swiped away, using
   the (topic, groupId, code) routes streamed from the UI isolate through the
   heartbeat pings — so mobile-network messages also produce notifications
   without the UI engine.

## Consequences

### Positive

* Chat works between any two devices with internet access, regardless of
  network type — no signaling server, no user accounts, no pairing.
* The broker cannot read, forge, or replay message content (AEAD + AAD).
* Self-hosting migration is a two-constant change (`kRelayBrokerHost/Port`).
* Existing UDP path is untouched — LAN scenarios keep working identically,
  and cross-transport duplicates are absorbed by the idempotent ingest.

### Negative / Limitations (documented, accepted for V3.0.5)

* **Public broker reliability**: `broker.emqx.io` is free shared
  infrastructure with no SLA. Outages degrade to LAN-only + history sync.
* **Topic entropy**: the invite code has ~32 bits of entropy (first 8 hex
  chars of the group UUID). An attacker who brute-forces the topic finds
  only opaque ciphertext — decrypting additionally requires the 122-bit
  group UUID. Passive enumeration of topics is not supported by the broker.
  Still, the topic is discoverable in principle; a self-hosted broker with
  per-group ACLs is the production-grade answer.
* **Delivery while fully offline**: QoS-1 queues on a public broker are
  short-lived and session-bound (clean session). Messages published while
  the recipient has no relay connection are healed by the history sync when
  the app comes back — not by the broker.
* **No WebRTC yet** (ADR-002): direct P2P over the internet (data channels
  with TURN) remains the long-term transport; the relay is deliberately
  layered behind the same `CommunicationService` interface so the swap is
  invisible to business modules.

## Verification

* `test/domain/relay_codec_test.dart` — derivation determinism, round-trip,
  wrong-key / wrong-group / tamper rejection, malformed bodies.
* `test/domain/hybrid_communication_service_test.dart` — type allowlist,
  route gating, encrypted publish, decrypted dispatch, QoS-1 dedup,
  foreign-group topic isolation.
* End-to-end device test: both devices on cellular data (Wi-Fi off), send
  messages both ways, verify chat + history + notifications.
