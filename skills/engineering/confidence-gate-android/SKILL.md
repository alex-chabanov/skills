---
name: confidence-gate-android
description: >
  Android/Kotlin version of the confidence gate. Use this INSTEAD of the general confidence-gate
  in any Android project (build.gradle[.kts] + AndroidManifest.xml present) BEFORE any commit, PR,
  or claiming work is "done". Evaluates implementation quality with brutal honesty on a 1–10 scale
  across the 6 general dimensions PLUS 6 Android-specific ones (lifecycle, concurrency, leaks,
  performance, compatibility, build/release), blocks progress if score < 10, and runs investigation
  loops to reach 10/10. MUST be invoked at the confidence phase of any Android workflow. Trigger on:
  "confidence check", "confidence gate", "am I ready to commit", "rate my solution", "confidence",
  or whenever reaching the final phase before commit in an Android/Kotlin codebase. You CANNOT say
  "done" or propose a commit without completing this gate. Non-negotiable at all complexity levels.
---

# Confidence Gate — Android

## When to use this instead of the general gate

Use **this** skill, not `confidence-gate`, whenever the repo is an Android/Kotlin project. Signals:

- `build.gradle` or `build.gradle.kts` + `settings.gradle[.kts]` at the root
- `AndroidManifest.xml` and an `app/` (or feature) module
- Kotlin sources with `androidx.*` / Compose / Coroutines imports

This gate is a **superset**: it includes all 6 general dimensions and adds 6 Android-specific ones. In an Android repo, run only this one — never both. It writes the same `confidence.md`, so the global commit rule is satisfied unchanged.

## Core Principle

**You cannot claim completion without a 10/10 confidence score.**

This is not a formality — it's a hard gate. A score below 10 means something is wrong.
Honest self-assessment now prevents production crashes, ANRs, Play Store rejections, bad reviews,
and broken trust.

```
NO COMMIT. NO "DONE". NO PR. WITHOUT 10/10.
```

## The Scale

| Score | Meaning |
|-------|---------|
| **10** | Ready to ship to production without hesitation. Zero known risks. |
| 9 | Almost there — one small thing nags. Not ready. |
| 8 | Significant gaps. Multiple concerns. |
| ≤7 | Serious problems. Do not proceed. |

**There is no "good enough". 9 = blocked, same as 3.**

## Step 1 — Read All Artifacts

Before scoring, read everything relevant:
- Spec / requirements (`spec.md`, task description, or user's original request)
- Implementation plan (`plan.md`, `tasks.md`)
- All modified source files (Kotlin, XML layouts, `AndroidManifest.xml`, Gradle files, resources)
- Test results — unit (`testDebugUnitTest`), instrumented (`connectedDebugAndroidTest`), lint, detekt
- Review feedback if any (`audit.md`, review comments)
- Any previous confidence attempts in `confidence.md`

Do not skip this. Scoring without reading is dishonest.

## Step 2 — Score with Brutal Honesty

Evaluate across these dimensions. **Score = lowest dimension score.** One weak area brings everything down.

### General dimensions (1–6)

1. **Correctness** — Does the implementation match every requirement? No missing cases?
2. **Tests** — Are tests actually passing? Do they cover edge cases and regressions?
3. **Code quality** — Readable, idiomatic Kotlin, no obvious smells or dead code?
4. **Safety** — No security vulnerabilities, no data-loss risks, no race conditions?
5. **Completeness** — Is everything done? No TODOs left in critical paths?
6. **Spec compliance** — Does the solution match the original intent, not just the literal words?

### Android dimensions (7–12)

7. **Lifecycle & state restoration** — Survives configuration change (rotation, dark mode, font scale) **and** process death. `SavedStateHandle` / `rememberSaveable` used for UI state that must outlive the process. No work tied to the wrong lifecycle scope.
   - Red flags: state held only in a field that resets on rotation; no `SavedStateHandle` for a multi-step form; `LaunchedEffect(Unit)` re-firing on every recomposition.

8. **Concurrency & main-thread safety** — No blocking I/O on the main thread. Coroutines launched in the correct scope (`viewModelScope`, `lifecycleScope`) with structured concurrency. Correct `Dispatchers`. Flows collected with the right lifecycle (`repeatOnLifecycle` / `collectAsStateWithLifecycle`).
   - Red flags: `runBlocking` on main; `GlobalScope.launch`; network/DB call without a dispatcher switch; collecting a flow in `onCreate` without lifecycle awareness.

9. **Memory & leaks** — No leaked `Context`, `Activity`, `View`, or `Fragment`. No leaked coroutines, listeners, or `LifecycleObserver`s. Bitmaps/cursors closed. (LeakCanary clean if runnable — see Verification.)
   - Red flags: `Activity` context stored in a singleton/companion; anonymous callback capturing a `View`; observer registered without removal.

10. **Performance & rendering** — No jank / dropped frames. Recomposition bounded (stable params, no unstable lambdas/allocations in hot paths). Cold-start and ANR risk considered. Heavy work off the UI/render path.
    - Red flags: allocation inside a Composable body or `onDraw`; unbounded list without keys; `runBlocking` in a Compose effect; expensive work in `onCreate`.

11. **Compatibility & fragmentation** — `minSdk` respected with API-level guards. Runtime permissions requested and the denial path handled. Behaves across configurations: dark mode, locale/RTL, orientation, large/small screens, font scale, and **accessibility** (content descriptions, touch-target size, TalkBack).
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

Do not be vague. "Might leak" is not acceptable. "`MainActivity` is stored in `AnalyticsManager`'s
companion object at line 31, leaking the whole Activity on every rotation" is acceptable.

If you cannot name the specific problem, investigate until you can.

## Step 4 — Verification & the Feedback-Loop Ladder

Run the **cheapest loop that covers the change**, escalating only as far as the change requires. Prefer fast loops; reach for slow ones only when the change touches that tier.

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
3. Re-run verification at the appropriate tier (tests, lint, detekt, release build)
4. Re-read relevant artifacts
5. Re-score honestly

**After 3 failed cycles:** Write `confidence.md` with current score, list what's blocking 10/10,
and tell the user what needs to be resolved before proceeding. Do not proceed.

## Step 6 — Write confidence.md

Always write this file regardless of score:

```markdown
# Confidence Gate — Android

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

- Unit tests: [pass/fail, count] — `./gradlew :app:testDebugUnitTest`
- Lint: [clean/N warnings] — `./gradlew :app:lintDebug`
- Detekt/ktlint: [clean/N issues]
- Release build (R8): [success/fail] — `./gradlew :app:assembleRelease`
- Spec review: [compliant/N gaps]

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
| **device-tier unverified** | Write `confidence.md` with BLOCKED — awaiting device verification. List the commands. Do NOT commit. |

## Global Constraints

These apply at ALL times, not just when the skill is explicitly invoked:

- **Never** say "done", "complete", "finished", "ready", "good to go" without 10/10
- **Never** propose a commit or PR without 10/10
- **Never** skip this gate because the task "seems simple"
- **Never** score 10 to avoid the work — that is dishonesty, not efficiency
- **Never** award 10 on a touched device-tier dimension you didn't actually verify
- If `/commit` is requested and `confidence.md` is absent or < 10/10: **block the commit**, run this gate first

## Anti-Patterns to Reject

| Temptation | Reality |
|-----------|---------|
| "It's 9/10, basically done" | 9 = blocked. No exceptions. |
| "Unit tests pass so it must be fine" | Unit tests passing ≠ 10/10. Check all 12 dimensions. |
| "`assembleDebug` works" | Debug build ≠ release. R8 can still strip and crash. Build release. |
| "I can't run instrumented tests, so I'll assume they pass" | Unverified device tier = capped score + human step. Never assume. |
| "It works on my API level" | Fragmentation breaks production. Check `minSdk` and configs. |
| "The user seems happy" | User satisfaction ≠ production readiness. |
| "I'll fix the leak in the next PR" | Known leak = not 10/10. Fix now. |
| "It's a small change, no need" | Gate applies regardless of size. |

## Example Output

```
Confidence Gate (Android) Assessment

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
