# Pokatuha V2 — Documentation

AI-ready specification for the Pokatuha Flutter app.

## File index

| File | What it describes |
|------|-------------------|
| `ARCHITECTURE_V2.md` | Core architecture: P2P + FCM, local-first storage, group→activity→chat model, privacy principles |
| `GROUPS_AND_ACTIVITIES.md` | Group types, permissions, activity lifecycle, tabs, archive, FAB behavior |
| `TELEGRAM_STYLE_CHAT.md` | Chat UI/UX: bubbles, reactions, voice, media, delivery states, read-only mode |
| `CHAT_P2P_QUEUE.md` | Message delivery flow: outbox, WebRTC, gossip relay, FCM wake-up, offline sync |
| `CHAT_AND_ENCRYPTION.md` | E2E encryption: X25519, Double Ratchet, AES-256-GCM, key hierarchy, Dart snippets |
| `design_tokens.md` | Colors, typography, spacing, radius, effects, glass surfaces, chat metrics, map colors |
| `MAPS_AND_GPS_FIX.md` | Map layers (OSM, CyclOSM, etc.), GPS permissions, live location, map action menu, Dart snippets |
| `ROUTES_IMPORT.md` | GPX/FIT/KML import, validation, preview, sharing rules, external handoff |
| `POLLS.md` | Polls inside activity: types, visibility, lifecycle, permissions, chat integration |
| `USER_DISCOVERY.md` | Identity model (no phone/email), discovery by nickname/QR/link, privacy settings |
| `THEMING_ENGINE.md` | Light/Dark/System themes, accent color propagation, adaptive breakpoints, glass surfaces |
| `FIGMA_IMPLEMENTATION.md` | Export rules, token extraction, Flutter build order, hard constraints for AI |

## How to use

1. Read `ARCHITECTURE_V2.md` first.
2. Pick the feature you are implementing.
3. Follow `design_tokens.md` and `FIGMA_IMPLEMENTATION.md` for UI.
4. Do not invent screens, tabs, or buttons outside these specs.
