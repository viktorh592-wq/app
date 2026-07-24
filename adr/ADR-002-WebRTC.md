# ADR-002

Title

Realtime Communication via WebRTC

Status

APPROVED

Date

2026-07-24

---

# Context

Pokatuha requires low-latency exchange of:

- GPS positions
- Chat messages
- Ride events
- Presence updates

The solution should avoid permanent backend infrastructure whenever possible.

---

# Decision

Use WebRTC for peer-to-peer communication during active rides (Live Mode).

---

# Alternatives Considered

WebSocket server

Rejected.

Requires dedicated backend.

MQTT broker

Rejected.

Requires centralized infrastructure.

Polling

Rejected.

High latency and battery consumption.

---

# Consequences

Positive

- Low latency
- Peer-to-peer
- Reduced server costs

Negative

- NAT traversal complexity
- Signaling requirements

---

# AI Guidance

WebRTC is the primary transport layer for Live Mode.

Do not replace it with WebSocket or MQTT unless explicitly requested.

---

End of document.