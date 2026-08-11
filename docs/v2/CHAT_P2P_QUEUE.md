# Pokatuha V2 — Chat P2P Queue & Delivery

Status: APPROVED
Depends on: ARCHITECTURE_V2.md, TELEGRAM_STYLE_CHAT.md

---

## 1. Core principles

- No central chat server stores messages
- Messages live only on user devices
- FCM = wake-up signal only (no message content inside)
- E2E encryption: X25519 + Double Ratchet
- Devices relay messages for offline peers

---

## 2. Message flow

1. Sender writes message
2. Encrypt locally on device
3. Store in local outbox
4. FCM wake-up sent to group topic (contains only group_id + message_id)
5. Online peers connect via WebRTC DataChannel
6. Message delivered directly
7. Receiving peer becomes relay for others
8. Offline peers sync later from any online peer

---

## 3. Delivery states (UI)

| State | Icon | Meaning |
|-------|------|---------|
| В очереди | Clock | No peers online, message waits |
| Отправляется | Single check (animated) | P2P transfer in progress |
| Доставлено | Single check | At least 1 peer received |
| Синхронизировано | Double check | All online peers received |
| Расшифровано | Shield (in details) | Recipient device confirmed |

---

## 4. FCM Wake-up payload

```json
{
  "topic": "group_abc123",
  "data": {
    "type": "new_message",
    "group_id": "abc123",
    "message_id": "msg-456"
  },
  "android": { "priority": "high" },
  "apns": { "payload": { "aps": { "contentAvailable": true } } }
}
```

FCM contains NO text, NO photos, NO sender name.

---

## 5. Offline handling

- If nobody online: message stays «В очереди» in outbox
- Sender may go offline after first successful delivery
- Gossip: online peers relay to other online peers
- Store-and-forward: offline peers download missed messages when they come back

---

## 6. Limits

- Pure P2P + gossip: up to 30 participants per group
- Above 30: relay cache server needed (future version)

---

## 7. History policy

- New group members see only messages from the moment they join
- No automatic backfill of old history
- Closed activity → chat becomes read-only forever
