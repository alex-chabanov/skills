# Coding style — Android (Java/Kotlin)

## Attitude to existing code

- **Do not mimic existing patterns just for consistency.** Follow this spec; old code is not authoritative.
- When you modify a file, refactor the parts you touch to this spec. Don't perpetuate smells (God class, deep nesting, hardcoded values, tight coupling) "to match surroundings".
- Behavior must stay unchanged during a refactor. Tests prove it.
- If the refactor cascades across **more than 3 files**, stop and explain the plan before continuing — let the user choose scope.
- Deleting dead code is part of touching code. No commented-out blocks left behind.

## Language defaults

- Kotlin for all new code. Java only when touching existing Java files or interop boundaries.
- Target JVM 17 in `kotlinOptions { jvmTarget = "17" }`. Match Gradle JDK.
- `-Werror` enabled. No suppressions without a `// reason:` comment on the same line.

## Immutability

- `val` over `var`. A `var` in a function body needs justification; a `var` at class scope needs a comment.
- Data classes for state. No mutable fields on `data class`es — copy with `.copy()`.
- Collections: `List/Set/Map` (read-only interface), not `MutableList/MutableSet/MutableMap`, on public API surfaces. Mutate locally, expose immutable.
- Compose state: `mutableStateOf(...)` wrapped in `private set` or hoisted via state holders. Never expose `MutableState` from a ViewModel — expose `StateFlow<UiState>` (immutable `UiState` data class).
- Room entities, DTOs, domain models: all `val` properties.

## Nullability

- Prefer non-null types. `?` is a deliberate signal, not laziness.
- Never use `!!` outside test code. Replace with `requireNotNull`, `checkNotNull`, or `?: error("reason")` so failures are explained.
- Platform types from Java APIs must be annotated at the boundary (`String` vs `String?`).
- Use `Result<T>` or a sealed `Outcome` type for fallible operations; do not return `null` to mean "failure".

## File size limits

- Hard cap: **500 lines per file** (Kotlin or Java). At 400 lines, start planning the split.
- Hard cap: **40 lines per function**. Composables that exceed 40 lines must be decomposed into smaller `@Composable` slots.
- Hard cap: **5 parameters per function**. More than 5 → introduce a parameter object (`data class`) or builder.
- Hard cap: **3 levels of nesting** inside a function. Use early returns, `let`/`run`, or extract.
- Class fan-out: a single class with more than 7 collaborators is a smell — extract a coordinator.

## Naming

- Packages: lowercase, no underscores. `com.app.feature.profile.data`.
- Classes: `PascalCase`. Composables: `PascalCase` (`ProfileScreen`, not `profileScreen`).
- Functions, vars: `camelCase`. Constants: `UPPER_SNAKE_CASE` inside `companion object` or top-level `const val`.
- Booleans read as questions: `isLoading`, `hasError`, `canSubmit`. Not `loading`, `error`, `submit`.
- Event handlers prefixed `handle`: `handleClick`, `handleSubmit`, `handleRefresh`. Lambdas passed to composables prefixed `on`: `onClick`, `onSubmit` (the param shape; the handler implementation uses `handle`).
- No meaningless names: `data1`, `temp`, `info`, `obj`, `result`, `item` (loop var exception allowed for `item` inside a 3-line block).
- Test functions: backtick-quoted sentences — `` fun `returns Loading then Success when refresh succeeds`() ``.

## Constants & magic values

- No magic numbers, no magic strings. Extract to `const val` (file-top or `companion object`) with a semantic name.
  - `delay(300L)` → `const val DEBOUNCE_MS = 300L`
  - `if (status == 401)` → use `HttpStatusCode.Unauthorized` or `const val HTTP_UNAUTHORIZED = 401`.
- Single-use constants are still constants. The name carries intent the literal cannot.
- Exception: 0, 1, -1, true, false in obvious contexts (`list.size - 1`, `index == 0`).
- No commented-out code. Delete it. Git remembers.

## Composition & boundaries

- Composition over inheritance. Use inheritance only for true is-a relationships (and prefer sealed hierarchies over open classes).
- Program to interfaces at module boundaries. `:feature:*` depends on `:core:*` **interfaces**, not concrete classes. Concretes live in `:core:*-impl` or are bound by DI.
- Unidirectional dependencies: `app → feature → domain → data`. Lower layers never know about upper layers. Catch violations in CI with module dependency checks.
- One primary constructor per class, and it must establish a valid object state. Secondary constructors only delegate. Android `View` subclasses with `@JvmOverloads` are the accepted exception.
- Never instantiate collaborators inside a constructor or `init` block. Receive them as constructor arguments (DI) or via a factory. Compose exception: `@Composable` functions take state + lambdas, not collaborators.
- Wrap primitives in `@JvmInline value class` when type confusion or invariants matter — IDs, monetary amounts, durations, units. Don't wrap speculatively: raw `Int`/`String` for fields with no invariant is fine.
  ```kotlin
  @JvmInline value class UserId(val value: String)
  @JvmInline value class Cents(val value: Long)
  ```
- Command/query separation: a public method either **returns a meaningful value** (query, no observable side effect) or **performs a single action** (command, returns `Unit`). Not both.
- Objects validate their own invariants in their constructor or factory. Callers do not re-validate. Pair this with the "validate at system boundaries" rule below — boundary code constructs the validated type once; everything downstream trusts it.

## Events vs direct calls

- Direct method calls inside a feature module. They trace cleanly through a stack.
- Events (MVI `Event` channel, see [patterns.md](patterns.md)) for **cross-feature notification**, navigation requests, and one-shot UI side effects (snackbar, toast, dialog).
- Don't promote everything to an event bus. Loose coupling has a debugging cost — pay it only where it buys real decoupling.

## Validation boundaries

- Validate at system boundaries only: user input, network responses, file I/O, IPC `Intent` extras, deep-link URIs.
- Internal calls trust their parameter types. No `requireNotNull` on a non-null Kotlin param, no re-checking a `String` is non-empty after the validating layer.
- Error messages name the failing operation and relevant values: `"refresh failed for userId=$userId, status=$status"`, not `"error occurred"`. Don't include secrets.
- Don't wrap whole function bodies in `try/catch`. Wrap the specific call that can throw. See [patterns.md](patterns.md) for the `safeCall` shape.

## Kotlin idioms

- Prefer `when` over chained `if/else if`. Exhaustive `when` on sealed types — no `else` branch.
- Scope functions: `let` for nullable transform, `apply` for builder-style config, `run` for block-with-result. Don't chain three of them.
- Extension functions for cohesive helpers, not for hiding mutation.
- Coroutines: structured concurrency only. Launch in a scope you own (`viewModelScope`, `lifecycleScope`, an injected `CoroutineScope`). No `GlobalScope`.
- Flows over `LiveData` for new code. `StateFlow` for state, `SharedFlow(replay=0)` for events.
- `suspend` functions must be main-safe or document the dispatcher they require.

## Java (when unavoidable)

- `final` on every field, parameter, and local that isn't reassigned.
- `@Nullable`/`@NonNull` on every parameter and return.
- No raw types. No `Vector`, `Hashtable`, `Stack`.
- Prefer `List.of`, `Map.of` (API 24+) over `Arrays.asList`/`new HashMap<>()`.

## Compose-specific

- Hoist state. Composables that own state are leaves only.
- Pass lambdas for events: `onClick: () -> Unit`. Avoid passing whole ViewModels into composables.
- `remember` for in-composition state, `rememberSaveable` across config change, ViewModel `StateFlow` for process death.
- Stable types only as parameters. Wrap unstable types in `@Immutable` or `@Stable`-annotated holders.
- Side effects: `LaunchedEffect`, `DisposableEffect`, `SideEffect`. Never call suspending code directly from a composable body.

## Formatting

- ktlint + detekt configured in `build-logic`. CI fails on violations.
- 4-space indent. Trailing commas on multi-line literals. Imports sorted; no wildcard imports except `kotlin.*` collections in tests if your style guide allows.
- One top-level declaration per file unless tightly cohesive (sealed hierarchy + helpers).

## Comments

- Default: no comment. Code explains itself.
- Write a comment only for **why** that isn't obvious from the code: a workaround for a vendor bug, a non-obvious invariant, a perf trade-off. Link to issue/PR/docs when relevant.
- KDoc on public API of `:core` modules; internal feature code does not need KDoc on every function.

See also: [testing.md](testing.md), [patterns.md](patterns.md).
