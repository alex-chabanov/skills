# Performance — model selection & runtime perf

Two scopes in this file:
1. **LLM model selection** for Claude-assisted work on this project.
2. **App runtime performance** rules for Swift / SwiftUI code.

---

## 1. Model selection (Haiku vs Sonnet vs Opus)

Default for hands-on coding in this repo: **Opus** (already running). Pick down only when the task fits.

### Haiku — pick for

- One-line edits, typo fixes, renames, formatting.
- Mechanical refactors with no judgement: import sorting, SwiftFormat auto-fixes, dependency version bumps.
- Translating a snippet between Swift/Objective-C with no design call.
- Generating boilerplate from a template (a new `Codable` DTO, a new MVI `Action` case mirroring an existing one).
- Summarizing a small file or crash log.
- High-volume parallel subagent dispatch where each task is shallow (e.g. "find all uses of X" sharded across packages).

**Skip Haiku when**: the task needs > 2 files of context, has any ambiguity, or touches security/concurrency.

### Sonnet — pick for

- Implementing a phase of an already-approved plan with clear file paths and line numbers.
- Writing tests against an existing, stable production type.
- Straightforward feature work in a familiar module: a new screen wired to an existing repository, a new endpoint following the data-layer pattern.
- Code review of a small PR (< 200 LOC) where the rubric is clear (style + obvious bugs).
- Most documentation work that isn't architectural.

**Skip Sonnet when**: the task is exploratory, the design isn't validated, or there's cross-module impact.

### Opus — pick for

- New architecture, new package, new domain model.
- Multi-file refactors with API-shape changes.
- Hard debugging — data races, actor-isolation bugs, retain cycles, main-thread hangs.
- Security review, threat modeling, crypto code.
- SwiftUI performance / `body` re-evaluation diagnosis.
- Cross-cutting work in `Core*` packages where blast radius is large.
- Any PR where "got it right the first time" matters more than throughput.

**Default for new conversations** unless the task is obviously small.

### Rule of thumb

- Reversible + narrow + clear → Haiku.
- Routine + scoped + pattern exists → Sonnet.
- Novel + wide + judgement required → Opus.

When unsure: Opus. The cost difference matters less than the cost of a wrong design call locked in by a smaller model.

---

## 2. App runtime performance

### Startup

- Cold-start budget: < 2s P50, < 4s P90 on a mid-tier device.
- Defer non-essential SDK init off the launch path; lazy-init analytics and crash reporters.
- No synchronous disk I/O or network on the main thread during `App.init` / first view's `.task`.
- Measure launch with `MetricKit` (`MXAppLaunchMetric`) and Instruments' App Launch template; track regressions release-over-release.

### Rendering

- Frame budget: 16ms (60Hz) / 8ms (120Hz / ProMotion). Anything that drops a frame is a perf bug.
- SwiftUI: keep view params `Equatable` value types so `body` re-evaluation is skipped; give `ForEach` stable `id`s; prefer `LazyVStack`/`LazyHStack`/`List` for large collections.
- Avoid nesting a `List`/lazy stack inside a non-lazy `ScrollView` that defeats laziness.
- Move expensive work out of `body` — `body` may run many times per frame. Cache derived values; don't allocate formatters per call.
- Images: load and downsample to the display size (e.g. via a caching image loader); never decode a full-res asset into a small frame.
- Animations: prefer `withAnimation` / `.animation(_:value:)`. Avoid per-frame allocations in custom `Animatable` work.

### Concurrency

- Main actor is for UI. Period. UI state types are `@MainActor`.
- `Task.detached` / background executors for CPU-bound work; `await` I/O on `URLSession`/file APIs which already run off-main.
- Isolate shared mutable state in an `actor`; don't reach for locks unless profiling demands it.
- Inject a `Clock` so tests can substitute time; never `Task.sleep` real time in production hot paths.
- No blocking the main thread on a semaphore to "await" async work. Restructure with `async`/`await`.

### Memory

- Profile with Instruments (Allocations, Leaks) before every release.
- Break retain cycles: `[weak self]` in escaping closures and long-lived `Task`s that capture `self`.
- Don't retain views/controllers in long-lived objects. View models never hold `UIView`/`UIViewController`/SwiftUI view references.
- Large buffers and image data: scope their lifetime; release promptly.

### Disk & DB

- SwiftData / Core Data / GRDB: index every column used in a predicate/sort. Verify with the query planner.
- Observe changes reactively (`@Query`, `FetchedResults`, GRDB observation) instead of polling.
- Batch writes in a single transaction. Don't loop single-row inserts.
- Prefer the modern store (SwiftData/Core Data/GRDB) over `UserDefaults` for anything structured.

### Network

- `URLSession` is shared/reused (one configured session), not created per request — reuse the connection pool.
- HTTP/2 by default; enable response compression server-side.
- Honor `Cache-Control`; use `URLCache` for cacheable GETs. Stale-while-revalidate for non-critical reads.
- Cancel in-flight requests when the owning view disappears (structured `Task` cancellation does this for free).

### App / bundle size

- Enable optimization and dead-code stripping for release. Strip symbols from the shipped binary.
- Use On-Demand Resources / asset slicing; ship per-scale assets, not all scales to every device.
- Audit the app thinning report and `Asset.car` size before each release. > 5% growth needs justification in the release notes.

### Benchmarks

- `XCTMetric` performance tests (`measure {}`) for hot algorithms (JSON parse, list diff, expensive transforms).
- MetricKit in production for real-world launch, hang, and scroll-hitch data.
- Benchmarks run on the same device class as the user base; results compared PR-over-PR.

See also: [coding-style.md](coding-style.md), [agents.md](agents.md).
