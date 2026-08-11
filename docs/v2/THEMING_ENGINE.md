# Pokatuha V2 — Theming Engine

Status: APPROVED
Depends on: ARCHITECTURE_V2.md, design_tokens.md

---

## 1. Theme modes

- Light
- Dark
- System (follows OS setting)

---

## 2. Accent color

User-selectable swatches (from UI Kit color picker):
- Violet (default)
- Blue
- Green
- Yellow
- Orange
- Red
- Pink
- Brown
- Gray
- Custom HEX

Propagation:
- Activity cards
- Internal headers and surfaces
- Map participant rings and route polyline
- Buttons and chips
- Chat outgoing bubble tint
- Poll bars and accents

---

## 3. Bubble style

- Telegram (default)
- Compact
- Rounded

---

## 4. Chat background

- Solid color
- Gradient
- Image
- Blur

---

## 5. Text size

Range: 80% — 130%

---

## 6. Adaptive breakpoints

| Device | Width |
|--------|-------|
| Minimum | 320dp |
| Base | 393dp |
| Large phones | 412–480dp |
| Tablets | 600dp+ |

Rules:
- No fixed widths in UI code
- Use Expanded, Flexible, LayoutBuilder
- Max chat content width on tablet: 560dp

---

## 7. Glass surfaces

- From UI Kit only (see design_tokens.md Effects)
- Active activity: glass + colored accent
- Started activity: glass + strong accent
- Finished activity: archive style (muted)
- Liquid Glass: 9-layer animated stack
