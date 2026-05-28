---
name: confidence-gate
description: >
  Use BEFORE any commit, PR, or claiming work is "done" — evaluates implementation quality with
  brutal honesty on a 1–10 scale, blocks progress if score < 10, and runs investigation loops to
  reach 10/10. Auto-extends to 12 dimensions in Android/Kotlin repos (lifecycle, concurrency, leaks,
  performance, compatibility, build/release) with a device-tier verification cap. MUST be invoked
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

## Android Mode — Auto-Detect

This skill auto-extends with 6 Android-specific dimensions when the repo is an Android/Kotlin
project. Signals (any one is sufficient):

- `build.gradle` or `build.gradle.kts` + `settings.gradle[.kts]` at the root
- `AndroidManifest.xml` and an `app/` (or feature) module
- Kotlin sources with `androidx.*` / Compose / Coroutines imports

If detected, run dimensions 1–12 and the device-tier verification ladder. Otherwise, run
dimensions 1–6 only.

## Step 1 — Read All Artifacts

Before scoring, read everything relevant:
- Spec / requirements (`spec.md`, task description, user's original request)
- Implementation plan (`plan.md`, `tasks.md`)
- All modified source files (and in Android: XML layouts, `AndroidManifest.xml`, Gradle, resources)
- Test results — unit, integration, linter; in Android also instrumented, lint, detekt/ktlint
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

### Android dimensions (7–12) — only if Android Mode is active

7. **Lifecycle & state restoration** — Survives configuration change (rotation, dark mode, font scale) **and** process death. `SavedStateHandle` / `rememberSaveable` used for UI state that must outlive the process. No work tied to the wrong lifecycle scope.
   - Red flags: state held only in a field that resets on rotation; no `SavedStateHandle` for a multi-step form; `LaunchedEffect(Unit)` re-firing on every recomposition.

8. **Concurrency & main-thread safety** — No blocking I/O on the main thread. Coroutines in correct scope (`viewModelScope`, `lifecycleScope`) with structured concurrency. Correct `Dispatchers`. Flows collected with the right lifecycle (`repeatOnLifecycle` / `collectAsStateWithLifecycle`).
   - Red flags: `runBlocking` on main; `GlobalScope.launch`; network/DB call without a dispatcher switch; collecting a flow in `onCreate` without lifecycle awareness.

9. **Memory & leaks** — No leaked `Context`, `Activity`, `View`, or `Fragment`. No leaked coroutines, listeners, or `LifecycleObserver`s. Bitmaps/cursors closed. LeakCanary clean if runnable (see Verification).
   - Red flags: `Activity` context stored in a singleton/companion; anonymous callback capturing a `View`; observer registered without removal.

10. **Performance & rendering** — No jank / dropped frames. Recomposition bounded (stable params, no unstable lambdas/allocations in hot paths). Cold-start and ANR risk considered. Heavy work off the UI/render path.
    - Red flags: allocation inside a Composable body or `onDraw`; unbounded list without keys; `runBlocking` in a Compose effect; expensive work in `onCreate`.

11. **Compatibility & fragmentation** — `minSdk` respected with API-level guards. Runtime permissions requested and denial path handled. Behaves across configurations: dark mode, locale/RTL, orientation, large/small screens, font scale, and **accessibility** (content descriptions, touch-target size, TalkBack).
    - Red flags: API call above `minSdk` without `Build.VERSION.SDK_INT` guard; permission used without a request flow; hardcoded strings/dimens; icon-only button with no content description.

12. **Build & release safety** — Release build compiles and runs. R8/ProGuard keep rules correct (no stripped reflection/serialization). Correct build variant/flavor. No debug-only code, logging of secrets, or `BuildConfig.DEBUG` branches leaking into release. Signing intact. Dependency/SDK versions sane.
    - Red flags: only `assembleDebug` verified; serialized/reflected class with no keep rule; `Log`/`println` of tokens; debug endpoint hardcoded.

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
rotation".

If you cannot name the specific problem, investigate until you can.

## Step 4 — Verification

### Non-Android

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

### Device-tier rule (cap, never silent-pass)

If a dimension you touched can **only** be verified at Tier 4–5 and you cannot run it in this environment:

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

**Mode:** [General | Android]
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

## Required Human Verification (device tier — caps score until done)

- [ ] Instrumented tests: `./gradlew connectedDebugAndroidTest`
- [ ] Leak check: run with LeakCanary, exercise [screen/flow]
- [ ] Performance: [Macrobenchmark / StrictMode on the affected path]
- [ ] Manual: [rotation, dark mode, TalkBack, low-API device, …]

## Decision

[Why this is/isn't 10/10. Be specific.]
```

## Gate Decision

| Score | Action |
|-------|--------|
| **10/10** | Write `confidence.md` with PASS. Proceed to commit/PR. |
| **< 10/10** | Write `confidence.md` with BLOCKED. Do NOT commit. Do NOT say "done". |
| **device-tier unverified (Android)** | Write `confidence.md` with BLOCKED — awaiting device verification. List the commands. Do NOT commit. |

## Global Constraints

Apply at ALL times, not just when the skill is explicitly invoked:

- **Never** say "done", "complete", "finished", "ready", "good to go" without 10/10
- **Never** propose a commit or PR without 10/10
- **Never** skip this gate because the task "seems simple"
- **Never** score 10 to avoid the work — that is dishonesty, not efficiency
- **Never** (Android) award 10 on a touched device-tier dimension you didn't actually verify
- If `/commit` is requested and `confidence.md` is absent or < 10/10: **block the commit**, run this gate first

## Anti-Patterns to Reject

| Temptation | Reality |
|-----------|---------|
| "It's 9/10, basically done" | 9 = blocked. No exceptions. |
| "Tests pass so it must be fine" | Tests passing ≠ 10/10. Check all dimensions. |
| "`assembleDebug` works" (Android) | Debug build ≠ release. R8 can still strip and crash. Build release. |
| "I can't run instrumented tests, so I'll assume they pass" (Android) | Unverified device tier = capped score + human step. Never assume. |
| "It works on my API level" (Android) | Fragmentation breaks production. Check `minSdk` and configs. |
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
