# Pokatuha V2 — Figma Implementation Guide

Status: APPROVED

---

## 1. Source of truth

- Figma file: `app-pokatuha`
- UI Kit: `UI kit.png` (exported)
- Screens: PNG 2x export from Figma

---

## 2. Export checklist

Export as PNG (2x, include background):
- Home / Groups
- Map (all states)
- Activity create
- Activity details (Main, Chat, Polls, Route tabs)
- Group screen
- Search users
- Profile
- Archive
- Settings / Appearance

---

## 3. Token extraction

From Figma Inspect / UI Kit:
- Colors: Primary, Primary Dark, Primary Deep, Card Surface, accents
- Typography: Inter, weights, sizes
- Spacing: 4, 8, 12, 16, 20, 24, 32, 40, 48, 56, 64, 72, 80
- Radius: 8, 12, 16, 20, 24
- Effects: Card Drop Shadow, FAB Shadow, Liquid Glass Border, Blurs

---

## 4. Flutter build rules

- Material 3
- Pixel-perfect vs exported PNG
- No web/React structure in Flutter code
- All sizes from design_tokens.md
- Reuse widgets (chips, buttons, cards, bubbles)
- Support Light / Dark / System
- Adaptive: 360, 393, 412, 480, 600+ dp
- No dummy buttons — every action has a real callback

---

## 5. Build order

1. ThemeData + ColorScheme
2. Typography scale
3. Components (buttons, chips, cards, chat bubbles, glass surfaces)
4. Screens

---

## 6. Hard constraints

- Exactly 4 tabs inside activity: Главная, Чат, Опросы, Маршрут
- No extra tabs (Photos, Weather, Stats as separate tabs)
- Glass effects from UI Kit only
- Buttons strictly per screenshots / UI Kit
- Activity color propagates to all inner surfaces
