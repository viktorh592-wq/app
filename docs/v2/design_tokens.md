# Pokatuha V2 — Design Tokens

Status: APPROVED
Source of truth: Figma UI Kit (`UI kit.png`)

---

## 1. Colors

### Primary palette
| Token | Visual | Usage |
|-------|--------|-------|
| `--color-primary` | Primary (violet) | Main buttons, accents |
| `--color-primary-dark` | Primary Dark | Pressed states |
| `--color-primary-deep` | Primary Deep | Headers, deep surfaces |
| `--color-card-surface` | Card Surface | Cards, glass base |
| `--color-lime-accent` | Lime Accent | FAB, chips, active states |
| `--color-yellow-accent` | Yellow Accent | Secondary actions, badges |
| `--color-green-accent` | Green Accent | Success, started status |

### Text & Background
| Token | Visual | Usage |
|-------|--------|-------|
| `--color-text-primary` | Text Primary | Headings, body text |
| `--color-text-secondary` | Text Secondary | Captions, hints |
| `--color-green-bg` | Green BG | Success backgrounds |
| `--color-chip-lavender` | Chip Lavender | Chips, pills |
| `--color-badge-red` | Badge Red | Notifications, errors |
| `--color-salmon` | Salmon | Warnings, soft alerts |
| `--color-glass-lime` | Glass Lime | Glass card tint |

> Exact hex values must be taken from Figma Inspect. Visual reference is in `UI kit.png`.

---

## 2. Typography

Font family: Inter

| Token | Weight | Size | Usage |
|-------|--------|------|-------|
| `--text-display` | Bold | 24 | Large titles |
| `--text-headline` | Medium | 20 | Screen titles |
| `--text-title` | Medium | 18 | Card titles |
| `--text-body` | Regular | 16 | Body text |
| `--text-body-medium` | Medium | 16 | Emphasized body |
| `--text-caption` | Regular | 14 | Labels, timestamps |
| `--text-button` | Medium | 14 | Button labels |
| `--text-pin` | Regular | 12 | Location pins, small tags |

---

## 3. Spacing

| Token | Value |
|-------|-------|
| `--space-1` | 4 |
| `--space-2` | 8 |
| `--space-3` | 12 |
| `--space-4` | 16 |
| `--space-5` | 20 |
| `--space-6` | 24 |
| `--space-7` | 32 |
| `--space-8` | 40 |
| `--space-9` | 48 |
| `--space-10` | 56 |
| `--space-11` | 64 |
| `--space-12` | 72 |
| `--space-13` | 80 |

---

## 4. Radius

| Token | Value |
|-------|-------|
| `--radius-sm` | 8 |
| `--radius-md` | 12 |
| `--radius-lg` | 16 |
| `--radius-xl` | 20 |
| `--radius-2xl` | 24 |
| `--radius-full` | 9999 (pills, avatars) |

---

## 5. Elevation & Effects

From UI Kit only. No custom shadows.

| Token | Usage |
|-------|-------|
| `--shadow-card-drop` | Activity cards |
| `--shadow-fab` | FAB buttons |
| `--shadow-text-drop` | Text on maps |
| `--glass-border` | Liquid glass borders |
| `--glass-inset-edge` | Top edge highlight on glass |
| `--blur-color-picker` | Color picker overlay |
| `--blur-frosted` | Frosted glass surfaces |
| `--blur-text-field` | Input fields on glass |
| `--blend-overlay` | Overlay (max blend) |
| `--blend-plus-lighter` | Light effects |
| `--blend-luminosity` | Glass luminosity |
| `--blend-multiply` | Darkening layers |

### Liquid Glass — Animated States
9-layer stack with varying opacity/blend modes. See `UI kit.png` bottom section.

---

## 6. Chat Metrics

| Token | Value |
|-------|-------|
| `--bubble-max-width` | 78% |
| `--bubble-radius` | 20 (large) |
| `--avatar-size` | 40 |
| `--avatar-size-sm` | 32 |
| `--group-timeout` | 5 min |
| `--reaction-size` | 28 |
| `--voice-max-duration` | 5 min |

---

## 7. Map & Activity

| Token | Usage |
|-------|-------|
| `--map-route-color` | Activity accent |
| `--map-ring-color` | Activity accent |
| `--map-avatar-ring` | Activity accent |
| `--status-planned` | Purple |
| `--status-active` | Blue |
| `--status-started` | Green |
| `--status-finished` | Orange |
| `--status-cancelled` | Red |

---

## 8. Animation

| Token | Value |
|-------|-------|
| `--duration-fast` | 150ms |
| `--duration-normal` | 300ms |
| `--duration-slow` | 500ms |
| `--ease-default` | ease-in-out |

---

## 9. Icons

Weather icon pack: 36 icons (see `UI kit.png` center). Use as vector assets.

---

## 10. Color Picker

User-selectable accent palette (circular swatches):
- Violet (default)
- Blue
- Green
- Yellow
- Orange
- Red
- Pink
- Brown
- Gray

Selected color propagates to: cards, headers, map rings, buttons, chips, chat accents, poll accents.
