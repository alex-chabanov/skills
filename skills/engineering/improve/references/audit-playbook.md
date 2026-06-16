# Audit Playbook

What to look for, per category. Each subagent (or direct audit pass) gets the relevant section plus the **Finding format** at the bottom. Adapt depth to repo size — a 2K-line CLI gets a lighter pass than a 500K-line monorepo.

A finding is only a finding with evidence. "Probably has N+1 queries somewhere" is not a finding; `orders/api.ts:142 issues one query per order item inside a loop` is.

---

## 1. Correctness / Bugs

The highest-trust category — real bugs found by reading, not speculation.

- Error handling: swallowed exceptions, empty catch blocks, `catch (e) { console.log(e) }` on critical paths, missing error states in UI code.
- Async hazards: unawaited promises, race conditions on shared state, missing cancellation/cleanup (stale closures in React effects, listeners never removed).
- Null/undefined flows: non-null assertions (`!`) on values that can be null, optional chaining hiding a value that must exist, unchecked array indexing.
- Boundary conditions: off-by-one, empty-collection handling, timezone/locale assumptions, integer overflow in counters/IDs.
- State machines: impossible-state combinations representable in types, status enums with unhandled branches (look for `default:` that silently no-ops).
- Concurrency: check-then-act on shared resources, missing transactions around multi-write operations, idempotency of retried operations (webhooks, queues).
- Type escape hatches: `any` / `as` casts / `@ts-ignore` clusters — each one is a place the compiler was overruled.
- Resource leaks: unclosed handles, connections, subscriptions; missing `finally`.
- **Mobile lens (Android/Apple):** lifecycle bugs — work tied to the wrong scope (Activity/Fragment recreation on config change, `ViewModel` vs UI scope, SwiftUI view-identity churn), state lost across process death / not restored from `SavedStateHandle` or `onSaveInstanceState`. Concurrency — coroutines launched on a lifecycle scope that outlives the consumer, `GlobalScope` leaks, work that should be on `lifecycleScope`/`viewModelScope`; Swift `Task` not cancelled, missing `@MainActor`, actor-isolation escapes. Main-thread blocking — disk/network I/O on the UI thread (StrictMode-detectable), heavy work in `onBindViewHolder`/`body`. Memory — retain cycles (`[weak self]`/`[unowned self]` missing in closures and delegates), Context/View captured by long-lived objects, unremoved observers/listeners.

## 2. Security

Review only what is directly supported by code evidence. Keep findings framed as defensive maintenance: identify the code pattern, explain the production impact, and describe the remediation. Keep plans at the level of code changes, configuration changes, and tests; do not include runnable demonstration strings or step-by-step misuse details.

**Handling rule:** never copy a secret value into a finding or plan — those files get committed. Reference the `file:line` and credential type only ("Stripe live key at `config.ts:12`"), and the fix sketch always includes rotation, not just removal (a committed secret is burned even after deletion).

**By-design is not a finding:** standard platform conventions are intentional behavior — honoring `https_proxy`/`NO_PROXY`, reading `~/.netrc`, an explicitly local dev tool shelling out to configured package managers. A tradeoff explicitly recorded in an ADR or decision doc is likewise settled, not a finding. Flag these only when the *implementation* adds risk beyond the convention or the documented decision itself — and note that a **stale ADR is itself a finding**: if the code has drifted from what the decision doc says, report the decision drift (the doc or the code is wrong; either way the team should know), don't use the doc to suppress it.

- Credential hygiene: hardcoded keys/tokens/passwords, credentials in committed `.env` files, credentials logged or persisted in event/history stores. Findings should name only the credential type and location, then recommend removal, rotation, and a safer configuration path.
- Data crossing into interpreters or privileged APIs: SQL or shell operations assembled from request data (SQL/command injection), HTML sinks fed by user-controlled content (XSS), dynamic execution APIs used with runtime input, or filesystem paths derived from request data (path traversal). Describe the safer API or validation boundary; do not provide runnable examples.
- Access control: endpoints/server actions that lack server-side identity checks, authorization enforced only in the client, object access by ID without ownership or tenant checks (IDOR), or missing request authenticity checks (CSRF) on state-changing routes.
- Input contracts: API boundaries that trust request bodies without schema validation, file upload handling without clear type/size/storage constraints, or broad object assignment from request data into persistence models (mass assignment).
- Dependency posture: run the ecosystem's audit command (`npm audit`, `pip-audit`, `cargo audit`) in read-only mode. Report only critical/high advisories that affect reachable runtime code or build/distribution paths; avoid low-signal audit noise.
- Production configuration: overly broad CORS where credentials are allowed, missing response-hardening headers (e.g. CSP) where sensitive browser surfaces exist, cookies missing appropriate `HttpOnly`/`Secure`/`SameSite` attributes, or debug/verbose behavior enabled in production configuration.
- Data minimization: PII or sensitive operational data in logs, stack traces returned to clients, or internal error details exposed through API responses.
- **Mobile lens (Android/Apple):** the MASVS surface. Insecure storage — secrets/tokens in plain `SharedPreferences`/`UserDefaults` or world-readable files instead of `EncryptedSharedPreferences`/Keychain/Keystore. Exposed surface — `android:exported="true"` components without permission guards, intent-filter / deep-link / App-Links handlers that trust unvalidated input, `android:allowBackup="true"` on apps holding sensitive data. WebView — `addJavascriptInterface` on untrusted content, `setJavaScriptEnabled` with remote URLs, `setAllowFileAccess`. Transport — disabled cert validation, missing pinning where threat model needs it, Android cleartext (`usesCleartextTraffic`) or iOS ATS exceptions. Note: report only code-evidenced issues, name the manifest/plist line, and keep the fix at the config/code level — never include a runnable exploit.

## 3. Performance

Look for the algorithmic and architectural wins, not micro-optimizations.

- N+1 patterns: query/fetch per item inside loops or per list-row rendering; missing batching or dataloader.
- Wrong complexity: nested scans over the same collection, repeated `find`/`filter` inside hot loops where a Map keyed lookup belongs.
- Caching gaps: identical expensive computations or fetches repeated per request/render; missing memoization at clear function boundaries; no HTTP/data-layer caching on stable data.
- Payload size: over-fetching (select *, full objects where IDs suffice), missing pagination on unbounded lists, large JSON shipped to clients.
- Frontend (if applicable): bundle composition (heavyweight deps for trivial use), missing code-splitting on rarely-hit routes, unoptimized images/fonts, client-side fetching for data available at render time, render waterfalls. For React/Next.js, defer to the repo's framework conventions and any installed best-practices guidelines.
- Backend: synchronous work that belongs in a queue, missing indexes implied by query patterns (flag for verification — don't claim without schema evidence), connection-per-request patterns where pooling exists.
- Build/CI: slow CI from missing caching, redundant pipeline steps, test suites that could parallelize.
- **Mobile lens (Android/Apple):** Compose/SwiftUI recomposition — unstable parameters forcing recomposition (non-`@Stable`/`@Immutable` types, unstable lambdas, reads of state too high in the tree), missing `key` in lazy lists, work in a composable `body`/`@ViewBuilder` that should be hoisted or `remember`ed. Main-thread cost — I/O or decoding on the UI thread, jank from heavy `onDraw`/layout passes, overdraw. App weight & startup — APK/App-Bundle size, unstripped resources, missing R8/Proguard shrinking or over-broad keep rules (defer to an `r8`-style analysis if available), cold-start work in `Application.onCreate`/`@main`. Images & memory — full-resolution bitmaps where thumbnails suffice, missing image-loader caching (Coil/Glide/Kingfisher), leaks surfaced by LeakCanary. "Bundle composition" above is web-specific — map it to APK/bundle size here.

## 4. Test Coverage

The goal is not a percentage — it's *which untested code is dangerous*.

- Map the critical paths (money, auth, data mutation, the feature the repo exists for) and check which have zero or trivial coverage.
- Modules with high churn (git log) + no tests = top refactor risk; flag as "characterization tests first" candidates.
- Existing test quality: tests that assert nothing meaningful, heavy mocking that tests the mocks, snapshot tests nobody reads, flaky patterns (real timers, real network, order dependence).
- Missing test layers: unit-only suites with zero integration coverage on API boundaries, or the inverse (slow E2E for what a unit test would catch).
- Verification infrastructure: is there a one-command way to know the codebase works? If not, that's finding #1 and a prerequisite plan for any risky change.
- **Mobile lens (Android/Apple):** mind the unit-vs-instrumented split — critical logic gated only behind slow on-device tests (Espresso, XCUITest) that rarely run is effectively untested; flag where a Robolectric/JUnit or XCTest unit test would catch it cheaper. Conversely, UI-state and navigation logic with zero Compose-UI-test / ViewModel-state coverage. Note tests that need an emulator/simulator the executor can't spin up — those plans need a host-runnable verify or an explicit "device required" STOP.

## 5. Tech Debt & Architecture

- Duplication: the same logic re-implemented in 3+ places (search for near-identical functions/components); divergent copies that have drifted.
- Layering violations: UI importing from data layer internals, circular dependencies, "utils" modules that became a junk drawer with high fan-in.
- Dead code: unexported-and-unused modules, feature flags fully rolled out but still branching, commented-out blocks with no explanation, deps in the manifest no longer imported.
- God objects/modules: files an order of magnitude larger than the repo median that everything touches; functions with double-digit parameters or deep conditional nesting.
- Inconsistent patterns: three ways of doing data fetching / error handling / styling in the same repo — pick the winner (the one the team converged on most recently) and plan the consolidation.
- Abstraction mismatches: premature abstractions with a single implementation, or missing abstractions where the same change always requires touching N files in lockstep.
- **Mobile lens (Android/Apple):** god UI controllers — massive `Activity`/`Fragment`/`ViewController` or SwiftUI views doing networking, persistence and presentation instead of delegating to a ViewModel/repository (the classic mobile layering smell). Business logic stranded in the UI layer where no unit test can reach it. Module/target structure — a single monolith module where feature/core boundaries would isolate build and test; inconsistent presentation patterns (MVVM vs MVI vs raw callbacks) across screens. If a module-structure skill exists, name it in the consolidation plan.

## 6. Dependencies & Migrations

- Major-version lag on core framework/runtime (not every minor bump — the ones with real cost to staying behind: EOL, security-fix cutoffs, ecosystem incompatibility).
- Deprecated APIs in use that have announced removal timelines.
- Abandoned dependencies (no release in years, archived repos) on critical paths.
- Duplicate dependencies solving the same problem (two date libs, two HTTP clients).
- Lockfile/manifest drift, version pinning inconsistencies across a monorepo.
- For each migration candidate, estimate blast radius (files touched) — that drives effort and whether to recommend it at all.
- **Mobile lens (Android/Apple):** version lag with real cost — Android Gradle Plugin / Gradle / Kotlin / `compileSdk` & `targetSdk` (Play Store mandates a minimum target each year), Jetpack libraries past their `compose-bom` line, Swift tools / deployment target, SwiftPM vs CocoaPods drift. Deprecated platform APIs with deadlines (e.g. edge-to-edge enforcement, scoped storage, billing-library cutoffs, deprecated `LocalBroadcastManager`/`AsyncTask`). These are often the single highest-leverage findings on a mature app — but blast radius is large; size it honestly and prefer a staged plan. If a focused migration skill exists for the candidate, name it in the plan's toolkit rather than re-deriving the steps.

## 7. DX & Tooling

- Missing or broken: typecheck script, lint config, formatter, pre-commit hooks, editorconfig.
- Slow feedback loops: dev-server or test startup measured in minutes, no watch mode, CI without caching.
- Onboarding friction: README setup steps that are wrong/incomplete, undocumented required env vars, no `.env.example`.
- Missing `CLAUDE.md`/`AGENTS.md` — for repos where agents will execute the plans, this is high-leverage: recommend one and include its outline as a plan.
- Error messages/logging: unstructured logs on services, missing request IDs/correlation, debugging requiring code changes.

## 8. Docs

Lowest default priority — only flag where absence has a concrete cost:

- Public API surface (published packages) without reference docs.
- Architectural decisions nobody can reconstruct (why X over Y) for actively-contested areas.
- Stale docs that are actively wrong (worse than missing) — setup instructions, API examples that no longer compile.

## 9. Direction — features & where to take this next

Forward-looking: not what's broken, but what this codebase wants to become. **Grounding rule:** every suggestion must cite evidence from the repo itself — a suggestion that could apply to any project in the category ("add dark mode", "add AI") is noise, not a finding. Sources of grounded direction signal:

- **Unfinished intent**: TODO/FIXME clusters around one theme, feature flags never rolled out, stubbed or half-built modules, commented-out feature code, abandoned mid-feature work visible in git history.
- **Stated-but-undelivered**: README/docs/roadmap promises with no corresponding code, CLI flags or config options that are no-ops, issue templates for features that don't exist. A PRD or `PRODUCT.md` that names users, use cases, or a direction the code hasn't caught up to is the strongest grounding signal there is — prefer it over inferred intent, and never propose something a decision doc already rejected (note the contradiction instead).
- **Surface asymmetries**: one-directional pairs (export without import, create without bulk-create, webhooks out but not in), entities with CRUD minus one, a public API that internal code clearly needed and hand-rolled around.
- **The adjacent possible**: capabilities the existing architecture makes disproportionately cheap — a plugin system one interface away, a public API one route file from the existing service layer, an integration the data model already supports.
- **Friction worth productizing**: things users of this project evidently do by hand around it (visible in docs, examples, issues) that the project could absorb.

Direction findings use the standard format with two adaptations: **Impact** is product/user value (who wants this and why now), and **Confidence** reflects how grounded the evidence is — not certainty that it's the right call. Strategy belongs to the maintainer; the advisor's job is grounded options with honest trade-offs. Effort estimates here are coarser; say so. Plans for selected direction findings are usually a *design/spike plan* (investigate, prototype, define the API, list open questions) rather than a build-everything plan — scope them that way.

---

## Finding format

Every finding, from every category and every subagent, comes back in this shape:

```markdown
### [CATEGORY-NN] Short imperative title

- **Evidence**: `path/file.ts:123` — one-sentence description of what's there. (Repeat per location; 2–5 strongest locations, note "and ~N similar sites" if widespread.)
- **Impact**: What goes wrong / what's being paid because of this. Concrete: "every order-list render issues 1+N queries", not "suboptimal".
- **Effort**: S (hours) / M (a day-ish) / L (multi-day) — for the *fix*, including tests.
- **Risk**: What the fix could break; LOW/MED/HIGH plus one line why.
- **Confidence**: HIGH (read the code, certain) / MED (strong signal, needs verification) / LOW (smell, needs investigation). LOW-confidence findings may be reported but get an "investigate" plan, not a "fix" plan.
- **Fix sketch**: 1–3 sentences. Not the plan — just enough to judge effort honestly.
```

## Prioritization rubric

Order findings by **leverage = impact ÷ effort, discounted by confidence and fix-risk**. Tiebreakers:

1. Anything that unblocks other findings (verification baseline, characterization tests) floats up.
2. Security findings with HIGH confidence float above equivalent-leverage non-security findings.
3. Prefer findings whose fix has a clean verification story — executor models succeed at those.
4. "Not worth doing" is a valid verdict; record it with one line of reasoning so the user knows it was considered.
