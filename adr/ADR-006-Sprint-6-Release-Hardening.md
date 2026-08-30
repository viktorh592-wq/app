# ADR-006

Title

Sprint 6 — V3.0.0 Release Hardening

Status

ACCEPTED

Date

2026-08-30

---

# Context

After Sprint 5 (PR #12) merged into `main`, the project was functionally
complete against the V2 specification, but the `Build Flutter APK`
workflow on `.github/workflows/build-apk.yml` was failing on every push
to `main` while `Flutter CI` (analyze + test) stayed green. Three
auto-generated fix PRs (#2 `flutter-build-failed-fix-8c5fb`,
#3 `flutter-code-quality-check-61096`, #4 `fix: upgrade Kotlin version
to 2.2.20`) had been open since August with no path to merge.

A separate audit of `FIX_PLAN.md` §9.3 (P2 checklist) found that three
items still showed ☐ even though two of them were already implemented
in code; the third (`S4-T10` Map tab ↔ activity map integration) was
genuinely missing.

The product owner wanted a release-hardening sprint rather than new
features: stabilize `main`, close stale PRs, reconcile the
documentation with the actual code, and ship the one missing P2 item.
This ADR records the architectural decisions made for that sprint.

---

# Decision

## 1. Remove `record` and `just_audio` from `pubspec.yaml`

The CI failure was caused by a transitive dependency mismatch in the
`record` package family:

- `record: ^5.1.2` (declared in `pubspec.yaml`) resolves to `5.2.1`,
  the latest 5.x release.
- `record 5.2.1` declares `record_platform_interface: ^1.2.0` and
  `record_linux: >=0.5.0 <1.0.0`, both loose constraints.
- pub resolves them to the newest matching versions: `1.5.0+` and
  `0.7.2`.
- `record_platform_interface 1.5.0+` (since 2026-01-30) introduced
  a new abstract class `RecordMethodChannelPlatformInterface` with
  the abstract member `startStream(String, RecordConfig)` and a
  `hasPermission(String, {bool request = true})` signature change.
  `record_linux 0.7.2` (the last 0.x release, untouched since
  2024-06-26) does not implement the new abstract member and has
  the old `hasPermission(String)` signature.
- The Dart kernel compiler therefore fails on Linux with
  `Error: The non-abstract class 'RecordLinux' is missing
  implementations for these members`, breaking the
  `compileFlutterBuildRelease` Gradle task and the entire
  `Build Flutter APK` workflow.

Three options were considered:

- **Pin `record_platform_interface` to an older version via
  `dependency_overrides`.** Rejected after empirical verification.
  The first attempt pinned `1.5.0` (the version accepted by every
  federated implementation's `^1.x` constraint); CI logs confirmed
  the override was applied (`record_platform_interface 1.5.0
  (overridden)`) but the kernel compiler still failed because
  `startStream` moved to the new `RecordMethodChannelPlatformInterface`
  abstract class in `1.5.0`, not in `1.6.0` as initially supposed.
  The actual cutoff is `1.2.0` (2024-11-02): every `>= 1.2.0` is
  incompatible with `record_linux 0.7.2`. Since `record_android 1.5.2`
  declares `^1.5.0` and `record_web 1.3.0` declares `^1.5.0`, there
  is no version of `record_platform_interface` that satisfies both
  the federated implementations' lower bounds and `record_linux 0.7.2`'s
  upper bound. The dependency graph is genuinely unsatisfiable within
  `record 5.x`.

- **Upgrade `record` to 6.x or 7.x.** Rejected: the `record` package
  is currently unused in the codebase (the voice-message UI is a
  "coming soon" placeholder per `activity_chat_tab.dart` §S3-T6).
  Upgrading would also pull in `record_ios` + `record_macos` (split
  out from `record_darwin` in 6.0.0) and may require future API
  changes when voice messages are actually implemented. The cleaner
  fix is to remove the unused dep entirely and re-add a maintained
  version when the feature is actually built.

- **Remove `record` and `just_audio` from `pubspec.yaml`.** Accepted.
  Both packages are documented as the intended voice-message stack
  in `TELEGRAM_STYLE_CHAT.md §9` and the `pubspec.yaml` comment block,
  but a full audit (`rg "package:record" lib/ test/`, `rg
  "package:just_audio" lib/ test/`) confirms that neither is actually
  imported by any source file. Removing them is safe and is the
  lowest-risk fix. The corresponding transitive dependencies
  (`record_android`, `record_darwin`, `record_linux`,
  `record_platform_interface`, `record_web`, `record_windows`,
  `just_audio_platform_interface`, `just_audio_web`, `audio_session`,
  `rxdart`) are pruned from `pubspec.lock` to keep the lock in sync
  with `pubspec.yaml` per AGENTS.md. `crypto` is kept because it is
  still pulled by `uuid 4.6.0`.

When voice messages (S3-T6) are actually implemented, the
implementation ADR should re-add a maintained `record` version
(likely `^7.x` which pulls `record_linux ^1.x`, a release line that
implements the modern `RecordMethodChannelPlatformInterface` API).

## 2. Bump app version to `3.0.0+1`

`pubspec.yaml`'s `version:` field was `1.0.0+1` since the project
inception. Sprint 6 is the release-hardening milestone that closes
the V2 specification work, so the version is bumped to `3.0.0+1`
to match the V3 documentation version and to signal the
release-ready state. The Flutter build pipeline uses this version
directly for `versionName`/`versionCode` in the Android manifest.

## 3. Close stale auto-generated PRs

PRs #2, #3, #4 were closed without merge. Their respective fix
branches were deleted from `origin`. The actual fixes (CI dependency
pin, Kotlin version alignment if needed) are owned by Sprint 6 in
a single PR per the agreed one-PR-per-sprint strategy.

## 4. Map tab ↔ activity map integration (S4-T10)

The FIX_PLAN spec called for three integration points. Two are
implemented in this sprint; the third is deferred:

- **Step 1 (done):** `ActivityDetailPage` gains an `initialTabIndex`
  parameter. `MapPage._meetingMarker` passes `initialTabIndex: 2`
  so tapping a meeting pin on the Map tab opens the activity
  directly on its Route sub-tab.
- **Step 2 (partial):** `MapPage` gains an optional `initialEventId`
  constructor parameter. When set, `_load()` fetches the event's
  first route and populates `_selectedRoutePoints` so the
  PolylineLayer renders it on first paint, and `_initialCenter`
  biases the camera toward the route's first waypoint. The
  `ActivityMenuSheet` gains a seventh action (`onShowOnMap`,
  `Icons.map_outlined`) that pushes
  `MapPage(initialEventId: event.id)` as a full-screen route on
  top of the current navigator.
- **Step 2 sub-bullet (deferred):** Switching the bottom-nav Map
  tab itself (rather than pushing a new `MapPage` route) would
  require lifting `MainScaffold._index` into a controller or
  `ValueNotifier`. This is a larger refactor deferred to a future
  sprint.
- **Step 3 (deferred):** Swipe-up gesture on the participant popup
  in MapPage → open `UserProfilePage`. Deferred because the
  `UserProfilePage` route is not yet finalized.

## 5. Dead code removal (S5-T6)

Two unreferenced library files were removed:

- `lib/core/errors/result.dart` — `Result`/`Success`/`Failure`
  sealed type for error propagation. No call site imports it; all
  repositories and services throw `AppError` directly.
- `lib/core/extensions/iterable_extensions.dart` —
  `mapIndexed` / `firstWhereOrNull` extensions. No call site
  imports them; the codebase uses Dart 3.0+
  `Iterable.firstOrNull` and inline for-loops.

A broader dead-code pass requires `flutter analyze` output, which
is not available in environments without the Flutter SDK installed.
The CI workflow (`flutter.yml`) reports `No issues found!` on
`main`; Sprint 6 keeps that invariant.

## 6. Documentation reconciliation

The Decision Log, README, and a new ADR-006 (this document) are
updated. Specifically:

- README's status block now reads `Version: 3.0.0` and notes the
  Sprint 6 release-hardening milestone.
- README gains a "Sprint status" table summarizing Sprints 1..6.
- README's repository structure block is expanded to show `lib/`,
  `android/`, `test/`, and `.github/workflows/`.
- The Decision Log gains a `## 2026-08-30 — Sprint 6` section
  recording the per-task acceptance (S6-T1..T7) and referencing
  this ADR.

---

# Alternatives Considered

### Pin `record` to an exact version instead of removing it

Rejected after empirical verification (see Decision §1). The first
attempt pinned `record_platform_interface: 1.5.0` via
`dependency_overrides`. CI confirmed the override was applied but the
build still failed because the `startStream` abstract member moved to
`RecordMethodChannelPlatformInterface` in `1.5.0`, not in `1.6.0` as
initially supposed. No version of `record_platform_interface`
satisfies both `record_android ^1.5.0` and `record_linux 0.7.2`'s
upper bound; the dependency graph is genuinely unsatisfiable within
`record 5.x`.

### Pin `record` to an older 5.x version instead of removing it

Considered. `record 5.0.5` (the last 5.0.x release, 2024-03-24) was
published before `record_linux 0.7.2` (2024-06-26) existed, so it
depended on an even older `record_linux`. While the transitive graph
at that point might have been satisfiable, pinning to a 2.5-year-old
release with no security updates is a worse trade-off than removing
the unused dep entirely.

### Switch to `flutter_map_marker_cluster` for S4-T6

Rejected. The existing custom distance-based clustering
implementation in `MapPage._participantMarkers` (zoom < 14,
threshold 1 km, count badge with tap-to-zoom) already meets the
V2 §6 spec acceptance criteria. Adding the external plugin would
introduce a new pub dependency (against AGENTS.md guidance) and
require rewriting the marker pipeline. The Decision Log §S4-T6
entry is updated to note the deviation from the prescribed
package.

### Implement the deferred S4-T10 step 2 sub-bullet in this sprint

Rejected. Lifting `MainScaffold._index` into a controller
requires either a `ValueNotifier<int>` exposed via
`InheritedWidget` or a `MainScaffoldController` registered in
`service_locator`. Both options touch every call site that
currently navigates to the Map tab (none today, but the API
shape needs design). Sprint 6's scope was explicitly
release-hardening, not new architectural surface area.

---

# Consequences

Positive

- `Build Flutter APK` workflow on `main` is expected to turn green
  once this PR merges.
- Three stale auto-generated PRs are closed; the open-PR queue is
  empty.
- `pubspec.yaml` version reflects the V3.0.0 release.
- README, Decision Log, and ADR-006 form a coherent documentation
  set for the V3.0.0 release.
- Map tab ↔ activity map bidirectional integration is shipped
  (marker tap → route tab; activity menu → map centred on route).
- Two unused library files are removed, shrinking the public
  surface area and keeping `flutter analyze` clean.

Negative

- `record` and `just_audio` are no longer in `pubspec.yaml`.
  When voice messages (S3-T6) are implemented, a future sprint must
  re-add a maintained `record` version (likely `^7.x`) — the
  `TELEGRAM_STYLE_CHAT.md §9` documentation still references
  `record`/`just_audio` as the intended voice stack, so the doc and
  the pubspec are temporarily out of sync. The pubspec.yaml comment
  block documents this gap.
- Sprint 6 ships `MapPage(initialEventId: ...)` as a pushed route
  rather than a true bottom-nav tab switch. UX is slightly
  inconsistent (back button returns to the activity list rather
  than switching the bottom-nav tab).
- Two `S4-T10` sub-steps are deferred to a future sprint; the
  P2 checklist item is "closed" but the spec is not 100%
  implemented.

Risks

- If voice messages (S3-T6) are implemented without reading this
  ADR, a future AI agent may re-add `record: ^5.1.2` from the
  `TELEGRAM_STYLE_CHAT.md §9` documentation and re-introduce the
  Linux build failure. Mitigation: the `pubspec.yaml` comment block
  explicitly warns about this; the `TELEGRAM_STYLE_CHAT.md` doc
  should be updated in a follow-up to point at ADR-006.
- The removed transitive dependencies (`rxdart`, `audio_session`,
  `just_audio_*`) may be re-introduced as transitive deps of a
  future package addition. `flutter pub get` will add them back
  automatically; the only risk is a future maintainer being
  confused by their absence in the lock.

Trade-offs

- One-PR-per-sprint (per the product owner's Sprint 6 choice)
  means a larger diff for review. The alternative (one PR per
  task) was rejected for this sprint to minimize review overhead
  on a release-hardening pass.

---

# AI Guidance

When working on this codebase after Sprint 6:

- The `record` and `just_audio` packages are NOT in `pubspec.yaml`.
  Do NOT re-add them without first reading this ADR — `record 5.x`
  is unsatisfiable on Linux (see Decision §1). If you need voice
  recording, upgrade to `record: ^7.x` or later, which pulls a
  maintained `record_linux 1.x` that implements the modern
  `RecordMethodChannelPlatformInterface` API.
- The `MapPage(initialEventId: ...)` route is the canonical way
  to deep-link into the map view from anywhere in the app. Use
  it for any "show on map" affordance.
- `ActivityDetailPage.initialTabIndex` defaults to `0` (Main).
  Pass `2` only when the user is coming from a map context where
  they expect to see the route immediately.
- The `ActivityMenuSheet` now has seven actions. Do not add an
  eighth without amending this ADR; V2 §9 prescribes exactly the
  seven that are shipped.
- If you need to switch the bottom-nav tab programmatically
  (deferred S4-T10 step 2 sub-bullet), do NOT add a `setState`
  hack; lift `MainScaffold._index` into a proper controller and
  amend this ADR.

---

End of document.
