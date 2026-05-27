# Performance — model selection & runtime perf

Two scopes in this file:
1. **LLM model selection** for Claude-assisted work on this project.
2. **App runtime performance** rules for Android/Kotlin code.

---

## 1. Model selection (Haiku vs Sonnet vs Opus)

Default for hands-on coding in this repo: **Opus 4.7** (already running). Pick down only when the task fits.

### Haiku 4.5 — pick for

- One-line edits, typo fixes, renames, formatting.
- Mechanical refactors with no judgement: import sorting, ktlint auto-fixes, dependency version bumps.
- Translating a snippet between Kotlin/Java with no design call.
- Generating boilerplate from a template (a new DAO method, a new MVI Action that mirrors an existing one).
- Summarizing a small file or stack trace.
- High-volume parallel subagent dispatch where each task is shallow (e.g. "find all uses of X" sharded across modules).

**Skip Haiku when**: the task requires holding > 2 files of context, has any ambiguity, or touches security/concurrency.

### Sonnet 4.6 — pick for

- Implementing a phase of an already-approved plan with clear file paths and line numbers (matches `up:implementer-sonnet`).
- Writing tests against an existing, stable production class.
- Straightforward feature work in a familiar module: new screen wired to an existing repository, new endpoint following the repo's data-layer pattern.
- Code review of a small PR (< 200 LOC) where the rubric is clear (style + obvious bugs).
- Most documentation work that isn't architectural.

**Skip Sonnet when**: the task is exploratory, the design isn't validated, or there's cross-module impact.

### Opus 4.7 — pick for

- New architecture, new module, new domain model.
- Multi-file refactors with API-shape changes.
- Hard debugging — race conditions, lifecycle bugs, memory leaks, ANRs.
- Security review, threat modeling, crypto code.
- Anything Compose performance / recomposition diagnosis.
- Cross-cutting work in `:core:*` modules where blast radius is large.
- Any PR where "got it right the first time" matters more than throughput.

**Default for new conversations** in this repo unless the task is obviously small.

### Rule of thumb

- Reversible + narrow + clear → Haiku.
- Routine + scoped + pattern exists → Sonnet.
- Novel + wide + judgement required → Opus.

When unsure: Opus. The cost difference matters less than the cost of a wrong design call locked in by a smaller model.

---

## 2. App runtime performance

### Startup

- Cold-start budget: < 2s P50, < 4s P90 on a mid-tier device (Pixel 5 / equivalent).
- Use App Startup library for content-providers. Lazy-init analytics, crash reporters, and any non-blocking SDK.
- Baseline Profiles + Startup Profiles enabled for release. Generate via Macrobenchmark on every minor release.
- No disk I/O on the main thread during `Application.onCreate` or first activity's `onCreate`.

### Rendering

- Frame budget: 16ms (60Hz) / 8ms (120Hz). Anything that drops a frame is a perf bug.
- Compose: hoist state, use `key()` in `LazyColumn` items, mark UI models `@Immutable`. Run the Compose compiler metrics in CI for `:feature:*` modules.
- Avoid nested scrollables. `LazyColumn` inside `Column { verticalScroll() }` is forbidden.
- Bitmaps: load via Coil with explicit size; never `BitmapFactory.decodeFile` on a full-res image.
- Animations: prefer `animate*AsState`. Avoid `Animatable` chains that allocate per frame.

### Concurrency

- Main thread is for UI. Period.
- `Dispatchers.IO` for disk/network. `Dispatchers.Default` for CPU-bound. `Dispatchers.Main.immediate` for UI updates from already-on-main suspends.
- Inject dispatchers (`AppDispatchers` interface) so tests can substitute.
- `withContext(Dispatchers.IO)` at the lowest level (data source), not sprinkled in ViewModels.
- No `runBlocking` outside main()/tests/Workers.

### Memory

- Profile with Android Studio Memory Profiler before every release.
- LeakCanary in debug builds. Zero leaks on the merge candidate.
- Avoid retaining `Context` in singletons (use `applicationContext` only).
- ViewModels do not hold `View` / `Activity` / `Fragment` / `Composable` references.
- Bitmaps and large buffers: explicit `.recycle()` or scope-bound lifecycle.

### Disk & DB

- Room: indexed columns on every `WHERE`/`JOIN` field. Verify with `EXPLAIN QUERY PLAN`.
- Use `Flow<List<T>>` queries — Room observes invalidation; avoid manual polling.
- Batch writes in a transaction. Don't loop `insert()` per row.
- DataStore over `SharedPreferences` for any new key. Migrate at next touch.

### Network

- OkHttp client is a singleton. Reuse connection pool.
- Enable HTTP/2; enable response compression.
- Cache GET responses with `Cache-Control` honored. Stale-while-revalidate for non-critical reads.
- Image requests cancelled on scroll-off (Coil does this automatically — don't fight it).

### APK / AAB size

- R8 minify + resource shrinking enabled in release.
- App Bundle, not APK, for distribution.
- Per-density resources via splits; no full mdpi/hdpi/xhdpi/xxhdpi/xxxhdpi shipped together.
- Audit with `apkanalyzer` before every release. > 5% growth needs justification in the release notes.

### Benchmarks

- Macrobenchmark for startup + scroll perf on key screens.
- Microbenchmark for hot algorithms (JSON parse, list diff, expensive transforms).
- Benchmarks run on the same device class as the user base; results compared PR-over-PR.

See also: [coding-style.md](coding-style.md), [agents.md](agents.md).
