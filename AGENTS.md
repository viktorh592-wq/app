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
# Agent Workflow Rules (for Qwen Code / AI agents)

Before changing code read: README.md, AI_RULES.md, architecture/, adr/.

## Golden rules
- NEVER push directly to `main` (branch is protected).
- All changes go through branch + Pull Request.
- One task = one branch = one small focused PR.

## Branches / PRs
- Branch names: `fix/<short-desc>`, `feat/<short-desc>`, `chore/<short-desc>`.
- Before commit run: `flutter analyze` (0 issues) and `flutter test`.
- PR description must contain: cause, what changed, how verified.
- Do NOT merge your own PR — a human merges it.

## Commits
- Conventional Commits, English, imperative:
  `feat:`, `fix:`, `refactor:`, `test:`, `docs:`, `chore:`.

## Build / verify
- Deps: `flutter pub get`
- Check: `flutter analyze`, `flutter test`
- After editing l10n/*.arb: `flutter gen-l10n`
- Do NOT build APK locally — APK is built by CI
  (.github/workflows/build-apk.yml) on push to main.

## CI failures
- If CI failed: `gh run list --workflow=build-apk.yml --limit 3`,
  then `gh run view <id> --log-failed` (only failed steps),
  fix the root cause and open a PR.

## Architecture
- Respect layers: core / database / domain / presentation.
- Storage: Sembast (ADR-005). Entities: UUID v7, UTC timestamps,
  versioning, soft delete.
- No new pub dependencies without justification in the PR.

## Forbidden
- Force push, deleting branches, rewriting history.
- Editing pubspec.yaml without updating pubspec.lock.
- Disabling/skipping tests or analyze to make checks green.
- Committing secrets or tokens.
