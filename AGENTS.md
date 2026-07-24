# AGENTS.md

Instructions for AI coding assistants working on Pokatuha (complements AI_RULES.md).

## Verify commands

Run these before considering work complete:

```bash
flutter pub get      # resolve dependencies (also regenerates l10n)
flutter analyze      # static analysis — must report "No issues found!"
flutter test         # unit tests — must all pass
```

No code generation step is needed (storage is Sembast, pure-Dart — ADR-005).

## Localization

After editing `l10n/app_en.arb` or `l10n/app_ru.arb`, regenerate:

```bash
flutter gen-l10n
```

Never use Dart keywords as ARB keys (e.g. `continue`); they break generated
getters.

## Architecture reminders

- Local-First: never introduce a mandatory cloud backend (ADR-001).
- Storage: Sembast via `DatabaseService` (ADR-005). Entities extend
  `BaseEntity` (`toMap`/`applyMap`). Repositories own soft-delete filtering.
- Communication: WebRTC for Live Mode (ADR-002); FCM for wake-up only
  (ADR-003). Never transport chat/GPS/media via FCM.
- Maps: OpenStreetMap/MapLibre default (MapService). Weather: Open-Meteo only.
- Modules communicate through repository/service interfaces only.
