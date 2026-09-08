# ADR-010: NOSTR Relay Transport (Second Internet Leg)

**Status:** Accepted (V3.0.9)
**Date:** 2026-09-09
**Relates to:** ADR-001 (Local-First), ADR-002 (WebRTC Live Mode), ADR-008 (Local-Network UDP Transport), ADR-009 (Relay Transport for Mobile Networks)

## Context

The V3.0.5 MQTT relay (ADR-009) made chat work across networks, but user
testing showed it is fragile in practice: the leg depends on PUBLIC,
anonymous MQTT brokers (`broker.emqx.io`, a HiveMQ Cloud endpoint that
cannot accept anonymous connections, `test.mosquitto.org`). Public brokers
rate-limit aggressively — and in cellular networks every subscriber of an
operator shares a handful of CGNAT addresses, so a rate limit hits whole
carrier crowds at once. When all three brokers fail, chat over mobile data
stops.

The developer-run alternative (self-hosted broker) is not available: the
project has no server, and 152-ФЗ (RF personal data law) considerations
further discourage operating user-facing infrastructure.

A provider WITH an account was evaluated (HiveMQ Cloud free tier) and
rejected for now: it re-creates a provider relationship, requires
credentials to be shipped inside the APK, and still leaves the app
dependent on a single commercial vendor.

## Decision

Add a SECOND internet relay leg using the NOSTR protocol
(`NostrRelayConnection`), and run both legs concurrently behind a fan-out
(`FanoutRelayConnection`, factory `buildDefaultRelayTransport`):

1. **Protocol surface** — minimal NIP-01 subset over websocket
   (`web_socket_channel`):
   * publish: `["EVENT", event]`;
   * subscribe: `["REQ", subId, {"kinds":[20001], "#t":[topic]}]`;
   * the subscription id IS the relay topic string, so incoming
     `["EVENT", subId, event]` frames map back to (topic, body) directly.

2. **Ephemeral events** — kind 20001 (NIP-01 ephemeral range): relays do
   NOT retain them. This mirrors the MQTT leg's connected-subscribers-only
   semantics; missed messages are healed by the existing peer-to-peer
   history sync (nothing sensitive rests on third-party disks).

3. **Routing shared with ADR-009** — the SAME topic id
   (`"pokatuha/v1/g/" + hex(SHA-256(topic-v1|CODE))[:20]`) rides in the
   `t` tag; the SAME sealed body from `relay_codec` rides in `content`.
   Both transports key off identical route derivation, and the seal stays
   the only security boundary.

4. **Signing without identity** — relays reject unsigned events (NIP-01),
   so each app run generates a random secp256k1 keypair (BIP-340,
   `bip340` package) and signs its events. The keypair is NEVER persisted:
   it carries no identity, grants no reputation, and different runs are
   unlinkable. Event ids depend only on content, so both peers compute
   the same ids for the same body.

5. **Fan-out, not migration** — MQTT stays for existing installs; NOSTR is
   added in parallel. Publish goes to every connected leg, incoming frames
   from all legs merge into the same ingest (cross-leg duplicates are
   absorbed by the existing idempotency layer). Either leg can be removed
   later by editing the factory only.

6. **Relays** — four independent public relays connected in parallel
   (`relay.damus.io`, `nos.lol`, `relay.primal.net`, `nostr.mom`); one
   healthy relay is enough for delivery. Dropped relays reconnect on a
   fixed 15 s cadence.

## Alternatives Considered

**Self-hosted MQTT broker** — best control, rejected: no server available
to the project (ADR-009 already anticipates this as "a constant change"
when infrastructure appears).

**MQTT provider with authorization (HiveMQ Cloud free)** — works, but
ships broker credentials inside the APK, creates a vendor relationship and
a single point of commercial failure. Rejected for now; the fan-out keeps
it as a drop-in future leg.

**WebRTC DataChannels (ADR-002)** — signaling would still need a relay,
and cellular CGNAT usually forces a TURN server. More moving parts than
the problem needs (chat payloads are small and store-and-heal).

**Yggdrasil mesh** — the cleanest long-term P2P story, but requires a
VpnService integration (gomobile / yggdrasil-go) that conflicts with
users' own VPNs (Android allows one). Deferred; does not compete with
this ADR's scope.

## Consequences

Positive
* Chat over mobile networks no longer depends on anonymous public MQTT
  brokers being friendly to CGNAT addresses.
* No accounts, no credentials, no provider relationship anywhere.
* Ephemeral events + random per-run keys keep the 152-ФЗ surface minimal:
  relays hold only signed ciphertext tagged with a hashed topic, for as
  long as the socket is open.
* The relay abstraction proved its worth — the whole transport is one
  class behind the existing `RelayConnection` interface.

Negative
* Two long-lived sockets (MQTT + up to 4 websocket relays) — negligible
  traffic, small battery cost; the keep-alive task isolate uses the same
  fan-out.
* BIP-340 signing is pure Dart — a few tens of ms per published message,
  irrelevant at chat rates.
* Ephemeral delivery still needs a reachable peer OR a later persistent
  kind if offline delivery proves important (same trade-off as ADR-009).
* Public relays are community-run; a hostile relay can drop or duplicate
  frames (availability only) — the AES-GCM seal makes reading or forging
  impossible, and the ingest layer absorbs duplicates.
