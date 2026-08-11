# Pokatuha V2 — Polls

Status: APPROVED
Depends on: ARCHITECTURE_V2.md

---

## 1. Location

Inside activity only. Tab: «Опросы».

---

## 2. Poll types

- Single choice
- Multiple choice

---

## 3. Visibility modes

- Anonymous (votes hidden)
- Public (shows who voted for what)

---

## 4. Lifecycle

1. Create poll (admin or member if allowed)
2. Vote
3. Close manually or by deadline
4. View results

---

## 5. UI

- Uses activity accent color for bars and highlights
- Shows: question, options, vote counts, percentages
- Closed state: final results only, no more voting

---

## 6. Permissions

- Owner / Admin: create, close, delete
- Member: vote (create if group setting allows)

---

## 7. Chat integration

- Poll can be shared as a card to activity chat
- Chat card shows question + current status (open/closed)
