---
name: confidence-gate
description: >
  Use BEFORE any commit, PR, or claiming work is "done" — evaluates implementation quality with
  brutal honesty on a 1–10 scale, blocks progress if score < 10, and runs investigation loops to
  reach 10/10. Auto-extends to 12 dimensions in mobile/UI repos — Android/Kotlin and Apple/Swift
  (lifecycle, concurrency, leaks, performance, compatibility, build/release) with a device-tier
  verification cap. MUST be invoked
  at the confidence phase of any workflow. Trigger on: "confidence check", "confidence gate",
  "am I ready to commit", "rate my solution", "confidence", or whenever reaching the final phase
  before commit. You CANNOT say "done" or propose a commit without completing this gate.
  Non-negotiable at all complexity levels.
---

# Confidence Gate

## Core Principle

**You cannot claim completion without a 10/10 confidence score.**

Not a formality — hard gate. Score below 10 means something is wrong. Honest self-assessment now
prevents production failures, wasted review cycles, and broken trust.

```
NO COMMIT. NO "DONE". NO PR. WITHOUT 10/10.
```

## The Scale

| Score | Meaning |
|-------|---------|
| **10** | Ready to deploy without hesitation. Zero known risks. |
| 9 | Almost there — one small thing nags. Not ready. |
| 8 | Significant gaps. Multiple concerns. |
| ≤7 | Serious problems. Do not proceed. |

**No "good enough". 9 = blocked, same as 3.**

## Platform Mode — Auto-Detect

This skill auto-extends with 6 platform-specific dimensions when the repo is a mobile/UI project.
Detect the platform from these signals (any one is sufficient):

**Android Mode**
- `build.gradle` or `build.gradle.kts` + `settings.gradle[.kts]` at the root
- `AndroidManifest.xml` and an `app/` (or feature) module
- Kotlin sources with `androidx.*` / Compose / Coroutines imports

**Apple Mode** (iOS / iPadOS / macOS, Swift / SwiftUI)
- `Package.swift`, `*.xcodeproj`, or `*.xcworkspace` at the root
- `Info.plist` / `*.entitlements` and an app target
- Swift sources with `import SwiftUI` / `import UIKit` / `import Combine`

If a platform is detected, run dimensions 1–12 and that platform's verification ladder. Otherwise,
run dimensions 1–6 only. If signals for both appear (e.g. a KMP repo with an iOS app), run both
platforms' dimensions 7–12.

## Step 1 — Read All Artifacts

Before scoring, read everything relevant:
- Spec / requirements (`spec.md`, task description, user's original request)
- Implementation plan (`plan.md`, `tasks.md`)
- All modified source files (Android: XML layouts, `AndroidManifest.xml`, Gradle, resources; Apple: `Info.plist`, `*.entitlements`, asset catalogs, `.pbxproj`/`Package.swift`)
- Test results — unit, integration, linter; Android: instrumented, lint, detekt/ktlint; Apple: XCUITest, SwiftLint, SwiftFormat
- Review feedback if any (`audit.md`, review comments)
- Any previous confidence attempts in `confidence.md`

Do not skip. Scoring without reading is dishonest.

## Step 2 — Score with Brutal Honesty

Evaluate across these dimensions. **Score = lowest dimension score.** One weak area brings
everything down.

### General dimensions (1–6) — always

1. **Correctness** — Does implementation match every requirement? No missing cases?
2. **Tests** — Are tests actually passing? Cover edge cases and regressions?
3. **Code quality** — Readable, idiomatic, no obvious smells or dead code?
4. **Safety** — No security vulnerabilities, no data-loss risks, no race conditions?
5. **Completeness** — Everything done? No TODOs in critical paths?
6. **Spec compliance** — Solution matches original intent, not just the literal words?

### Platform dimensions (7–12) — only if a platform mode is active

Each dimension has the same intent on both platforms; apply the bullet matching the detected
platform. In a dual-platform repo, apply both.

7. **Lifecycle & state restoration** — UI state survives config change **and** process/scene termination.
   - *Android:* survives rotation, dark mode, font scale and process death. `SavedStateHandle` / `rememberSaveable` for state that must outlive the process. No work in the wrong lifecycle scope.
     - Red flags: state in a field that resets on rotation; no `SavedStateHandle` for a multi-step form; `LaunchedEffect(Unit)` re-firing every recomposition.
   - *Apple:* survives backgrounding and state restoration. `@SceneStorage`/`@AppStorage` (or `NSUserActivity` restoration) for state that must outlive termination. `@StateObject`/`@State` owned at the right level so it isn't recreated.
     - Red flags: state in a struct recreated each render; `.task`/`onAppear` work not cancelled on disappear; relying on in-memory state across a cold launch.

8. **Concurrency & main-thread safety** — No blocking I/O on the main thread; structured concurrency in a scope you own.
   - *Android:* coroutines in `viewModelScope`/`lifecycleScope`, correct `Dispatchers`, flows collected with `repeatOnLifecycle`/`collectAsStateWithLifecycle`.
     - Red flags: `runBlocking` on main; `GlobalScope.launch`; network/DB call with no dispatcher switch; collecting a flow in `onCreate` without lifecycle awareness.
   - *Apple:* UI state on `@MainActor`; `async`/`await` with structured tasks; shared mutable state isolated in an `actor`; types crossing concurrency domains are `Sendable`. No data races (run with the Swift concurrency / Thread Sanitizer).
     - Red flags: `DispatchSemaphore.wait()` on main to await async work; detached `Task` that outlives its owner uncancelled; mutable class shared across actors without isolation; `@unchecked Sendable` to silence a warning.

9. **Memory & leaks** — No leaked UI objects, no leaked async work.
   - *Android:* no leaked `Context`/`Activity`/`View`/`Fragment`, coroutines, listeners, or `LifecycleObserver`s. Bitmaps/cursors closed. LeakCanary clean if runnable.
     - Red flags: `Activity` context in a singleton/companion; callback capturing a `View`; observer never removed.
   - *Apple:* no retain cycles. `[weak self]` in escaping closures and long-lived `Task`s; no view/controller retained by a long-lived object. Instruments **Leaks/Allocations** clean if runnable.
     - Red flags: closure capturing `self` strongly in a stored `Task`/`Combine` subscription; delegate as a `strong` ref; `@escaping` handler retaining a view model cycle.

10. **Performance & rendering** — No jank / dropped frames; heavy work off the UI/render path.
    - *Android:* recomposition bounded (stable params, no unstable lambdas/allocations in hot paths). Cold-start and ANR risk considered.
      - Red flags: allocation in a Composable body or `onDraw`; unbounded list without keys; `runBlocking` in a Compose effect; expensive work in `onCreate`.
    - *Apple:* `body` re-evaluation bounded (`Equatable`/value params, stable `ForEach` ids); no expensive work or allocation in `body`; lazy stacks for large collections. Hitch / hang risk considered.
      - Red flags: formatter/date allocation inside `body`; `ForEach` over an index range with unstable ids; sync work in `body`; non-lazy `ScrollView` around a huge list.

11. **Compatibility & fragmentation** — Minimum OS respected with availability guards; permissions handled; behaves across configurations and **accessibility**.
    - *Android:* `minSdk` respected with `Build.VERSION.SDK_INT` guards. Runtime permissions requested with denial handled. Dark mode, locale/RTL, orientation, screen size, font scale, TalkBack, touch-target size, content descriptions.
      - Red flags: API above `minSdk` with no guard; permission used without a request flow; hardcoded strings/dimens; icon-only button with no content description.
    - *Apple:* deployment target respected with `@available`/`#available` guards. `Info.plist` usage strings present and denial/restricted/limited states handled. Dark mode, Dynamic Type, locale/RTL, size classes, VoiceOver labels, 44pt touch targets.
      - Red flags: API above the deployment target with no `#available`; permission used without a usage string or denial path; fixed font sizes ignoring Dynamic Type; image button with no accessibility label.

12. **Build & release safety** — Release configuration compiles and runs; no debug code or secrets leak.
    - *Android:* release build runs; R8/ProGuard keep rules correct (no stripped reflection/serialization); correct variant/flavor; no `BuildConfig.DEBUG`-only code or secret logging in release; signing intact; deps pinned.
      - Red flags: only `assembleDebug` verified; serialized/reflected class with no keep rule; `Log` of tokens; debug endpoint hardcoded.
    - *Apple:* **Release-configuration** build runs (optimizer + dead-code stripping exercised); no `#if DEBUG`-only code path leaking; no secret logging (`os.Logger` privacy correct); signing/entitlements intact; `Package.resolved` pinned and committed.
      - Red flags: only a Debug build verified; `print`/`os_log` of tokens; a debug-only base URL shipped; force-unwrap that only survives because of Debug timing; unpinned SPM dependency.

## Step 3 — For Every Point Below 10

For EACH point missing from 10, write:

```
Issue: [what exactly is wrong]
Risk: [what could break or go wrong in production]
Fix: [concrete action to resolve it]
```

Do not be vague. "Tests might fail" not acceptable. "The edge case where input is null in
`parseConfig()` at line 47 has no test and will throw NPE" is acceptable. In Android: "`MainActivity`
is stored in `AnalyticsManager`'s companion object at line 31, leaking the whole Activity on every
rotation". In Apple: "`ProfileViewModel`'s `Task` at line 31 captures `self` strongly and is never
cancelled — retain cycle held for the view's lifetime".

If you cannot name the specific problem, investigate until you can.

## Step 4 — Verification

### General (no platform mode)

Run tests, linter, and build relevant to the change. Capture pass/fail counts and any warnings.

### Android — Feedback-Loop Ladder

Run the **cheapest loop that covers the change**, escalating only as far as the change requires.
Prefer fast loops; reach for slow ones only when the change touches that tier.

| Tier | Loop | Command | Agent can run? |
|------|------|---------|----------------|
| 1 | JVM unit tests | `./gradlew :<module>:testDebugUnitTest` | ✅ |
| 1 | Lint | `./gradlew :<module>:lintDebug` | ✅ |
| 1 | Static analysis | `./gradlew detekt` / ktlint | ✅ |
| 2 | Robolectric / JVM Compose tests | `./gradlew :<module>:testDebugUnitTest` | ✅ |
| 3 | Release build (exercises R8) | `./gradlew :<module>:assembleRelease` | ✅ |
| 4 | Instrumented / Compose UI on device | `./gradlew connectedDebugAndroidTest` | ⚠️ device only |
| 4 | Leak detection | LeakCanary run | ⚠️ device only |
| 4 | Performance | Macrobenchmark / Perfetto / StrictMode | ⚠️ device only |
| 5 | Manual on-device QA, Play pre-launch report | — | ❌ human only |

### Apple — Feedback-Loop Ladder

Most iOS verification runs in the **Simulator**, which an agent often can drive — so the cap is
narrower than Android's. Only true-hardware checks are human-gated.

| Tier | Loop | Command | Agent can run? |
|------|------|---------|----------------|
| 1 | Unit tests (package) | `swift test` | ✅ |
| 1 | Lint | `swiftlint --strict` | ✅ |
| 1 | Format check | `swiftformat --lint .` | ✅ |
| 2 | Unit + snapshot/ViewInspector (Simulator) | `xcodebuild test -scheme <S> -destination 'platform=iOS Simulator,name=iPhone 15'` | ✅ |
| 3 | Release-config build (optimizer + dead-strip) | `xcodebuild build -scheme <S> -configuration Release` | ✅ |
| 4 | XCUITest UI flow (Simulator) | `xcodebuild test` with the UITest target | ✅ (simulator) |
| 4 | Leak / allocation profiling | Instruments (Leaks/Allocations) | ⚠️ device/real-run only |
| 4 | Performance / hitches | Instruments, MetricKit, hang detection | ⚠️ real device only |
| 5 | Manual on-device QA, TestFlight, App Review | — | ❌ human only |

### Device-tier rule (cap, never silent-pass)

If a dimension you touched can **only** be verified at a tier you cannot run in this environment
(Android Tier 4–5; Apple Tier 4 real-device / Tier 5):

1. The unverified dimension **caps the score below 10** — you may not award 10/10 on inspection alone.
2. Write the exact required command into `confidence.md` under **Required human verification**.
3. The gate stays **BLOCKED** until the human runs it and reports the result, at which point you re-score.

10/10 means actually verified — by the agent, or by a stated human run. Never assume green.

## Step 5 — Investigation Loop (max 3 cycles)

If score < 10 (and the gap is something you can fix, not a device-only verification):

```
Cycle 1: Launch SubAgent → investigate the specific issues → apply fixes → re-evaluate
Cycle 2: If still < 10 → launch SubAgent again → deeper investigation → fixes → re-evaluate
Cycle 3: Final attempt → if still < 10 → STOP, report blockers, do NOT proceed
```

Each cycle must:
1. Identify the root cause (not symptoms)
2. Apply actual fixes (not workarounds)
3. Re-run verification at the appropriate tier
4. Re-read relevant artifacts
5. Re-score honestly

**After 3 failed cycles:** Write `confidence.md` with current score, list what's blocking 10/10,
tell the user what needs to be resolved before proceeding. Do not proceed.

## Step 6 — Write confidence.md

Always write this file regardless of score:

```markdown
# Confidence Gate

**Mode:** [General | Android | Apple]
**Score: X/10**
**Cycles used: N/3**
**Status: [PASS — ready to commit | BLOCKED — issues remain | BLOCKED — awaiting device verification]**

## Assessment

[Summary of what was evaluated]

## Issues Found (if any)

### Issue 1
- **What:** ...
- **Risk:** ...
- **Fixed:** [yes/no — how]

## Verification Evidence

- Tests: [pass/fail, count]
- Linter: [clean/N warnings]
- Build: [success/fail]
- Spec review: [compliant/N gaps]

### Android-only (when Android Mode)
- Unit tests: `./gradlew :app:testDebugUnitTest`
- Lint: `./gradlew :app:lintDebug`
- Detekt/ktlint: [clean/N issues]
- Release build (R8): `./gradlew :app:assembleRelease`

### Apple-only (when Apple Mode)
- Unit tests: `swift test` / `xcodebuild test -destination 'platform=iOS Simulator,…'`
- SwiftLint: [clean/N issues]
- SwiftFormat: `swiftformat --lint .` [clean/N issues]
- Release build: `xcodebuild build -configuration Release`

## Required Human Verification (device tier — caps score until done)

**Android:**
- [ ] Instrumented tests: `./gradlew connectedDebugAndroidTest`
- [ ] Leak check: run with LeakCanary, exercise [screen/flow]
- [ ] Performance: [Macrobenchmark / StrictMode on the affected path]
- [ ] Manual: [rotation, dark mode, TalkBack, low-API device, …]

**Apple:**
- [ ] Leak/allocation: Instruments (Leaks) on [screen/flow]
- [ ] Performance: Instruments / MetricKit / hang detection on the affected path
- [ ] Manual on real device: [Dynamic Type, VoiceOver, dark mode, oldest supported OS, …]
- [ ] TestFlight / App Review pre-check if entitlements or permissions changed

## Decision

[Why this is/isn't 10/10. Be specific.]
```

## Gate Decision

| Score | Action |
|-------|--------|
| **10/10** | Write `confidence.md` with PASS. Proceed to commit/PR. |
| **< 10/10** | Write `confidence.md` with BLOCKED. Do NOT commit. Do NOT say "done". |
| **device-tier unverified (Android/Apple)** | Write `confidence.md` with BLOCKED — awaiting device verification. List the commands. Do NOT commit. |

## Global Constraints

Apply at ALL times, not just when the skill is explicitly invoked:

- **Never** say "done", "complete", "finished", "ready", "good to go" without 10/10
- **Never** propose a commit or PR without 10/10
- **Never** skip this gate because the task "seems simple"
- **Never** score 10 to avoid the work — that is dishonesty, not efficiency
- **Never** (Android/Apple) award 10 on a touched device-tier dimension you didn't actually verify
- If `/commit` is requested and `confidence.md` is absent or < 10/10: **block the commit**, run this gate first

## Anti-Patterns to Reject

| Temptation | Reality |
|-----------|---------|
| "It's 9/10, basically done" | 9 = blocked. No exceptions. |
| "Tests pass so it must be fine" | Tests passing ≠ 10/10. Check all dimensions. |
| "`assembleDebug` works" (Android) | Debug build ≠ release. R8 can still strip and crash. Build release. |
| "Debug build runs" (Apple) | Debug ≠ Release. Optimizer + dead-strip can change behavior; force-unwraps survive on Debug timing. Build Release config. |
| "I can't run instrumented tests, so I'll assume they pass" (Android) | Unverified device tier = capped score + human step. Never assume. |
| "I'll skip the Simulator UI test, looks fine" (Apple) | XCUITest runs in the Simulator — an agent can run it. Not running ≠ verified. |
| "It works on my API level" (Android) | Fragmentation breaks production. Check `minSdk` and configs. |
| "It builds on my iOS version" (Apple) | An API above the deployment target with no `#available` crashes on older OS. Check the floor. |
| "The user seems happy" | User satisfaction ≠ production readiness. |
| "I'll fix it in the next PR" | Known issues = not 10/10. Fix now. |
| "It's a small change, no need" | Gate applies regardless of size. |
| "I've done 3 cycles, I'll round up" | 3 failed cycles = escalate, not approve. |

## Example Output — General

```
Confidence Gate Assessment (General)

Reading artifacts...
[lists what was read]

Score: 7/10

Issues (3 points missing):
1. Issue: parseConfig() crashes on null input (line 47)
   Risk: NPE in production when remote config returns empty response
   Fix: Add null guard, add test for this case

2. Issue: No test for the retry logic timeout path
   Risk: Silent hang if server is slow — no timeout enforced
   Fix: Add test with mocked slow server, verify timeout fires

3. Issue: TODO comment left in syncToRemote() line 89
   Risk: Incomplete feature — deduplication logic is skipped
   Fix: Implement or explicitly defer with spec approval

Launching investigation cycle 1/3...
```

## Example Output — Android Mode

```
Confidence Gate Assessment (Android)

Reading artifacts...
[lists what was read]

Score: 6/10

Issues (4 points missing):
1. Issue: NoteListViewModel collects repo.notes in init {} without a dispatcher or
   lifecycle awareness (line 22)
   Risk: flow keeps collecting after the screen is gone — wasted work + potential leak
   Fix: expose as StateFlow via stateIn(viewModelScope); collect with
        collectAsStateWithLifecycle in the Composable

2. Issue: SyncWorker uses java.time.LocalDate (API 26) but minSdk is 21, no desugaring
   Risk: NoClassDefFoundError crash on API 21–25 devices in production
   Fix: enable core library desugaring or guard with Build.VERSION.SDK_INT

3. Issue: Only assembleDebug verified; @Serializable NoteDto has no R8 keep rule
   Risk: release build strips the serializer → runtime crash on first network call
   Fix: build assembleRelease, add keep rule / @Keep, re-verify

4. Issue: Instrumented test for the swipe-to-delete flow can't run here (no device)
   Risk: gesture + Room delete path unverified end-to-end
   Fix: REQUIRED human run — ./gradlew connectedDebugAndroidTest (caps score until done)

Launching investigation cycle 1/3 for issues 1–3...
(Issue 4 is device-tier: written to confidence.md as required human verification.)
```

## Example Output — Apple Mode

```
Confidence Gate Assessment (Apple)

Reading artifacts...
[lists what was read]

Score: 6/10

Issues (4 points missing):
1. Issue: ProfileViewModel starts a Task in init that captures self strongly and is
   never stored/cancelled (line 18)
   Risk: retain cycle — the view model and its view never deallocate; work keeps running
   after the screen is gone
   Fix: store the Task, cancel in deinit / .onDisappear, capture [weak self]; or move the
        load into .task {} on the view so cancellation is automatic

2. Issue: uses URLSession.shared.data(for:) decoded with try! into the model (line 44)
   Risk: any malformed/empty response crashes in production
   Fix: typed do/catch → map to DataError; remove try!

3. Issue: only the Debug build was verified; a force-unwrap in the paywall path survives
   on Debug timing
   Risk: Release config (optimizer) reorders init — crash on first launch in production
   Fix: xcodebuild build -configuration Release; replace ! with guard let; re-verify

4. Issue: Instruments Leaks on the photo-picker flow can't run on a real device here
   Risk: large-image retain path unverified on hardware
   Fix: REQUIRED human run — Instruments (Leaks) on device (caps score until done)

Launching investigation cycle 1/3 for issues 1–3...
(Issue 4 is real-device tier: written to confidence.md as required human verification.)
```
