# Testing — Android (Java/Kotlin)

## TDD baseline

- Red → green → refactor. Write the failing test first for any new behavior, bug fix, or regression.
- A bug report becomes a failing test before the fix lands. The test stays.
- Refactors do not need new tests, but must keep the existing suite green.

## Coverage targets

- Project-wide line coverage: **≥ 80%**. CI fails below threshold.
- `:core:*` modules: **≥ 90%** — they have no Android dependency, no excuse.
- ViewModels: **100% of state transitions and event emissions**. Coverage alone is not enough — assert state sequences.
- UI (Compose): smoke + critical-path instrumented tests, not coverage-driven.
- Exclude from coverage: generated code, DI modules, `Application` class, theme/resource files. Declare exclusions in `jacoco` config, not by deleting tests.

## Test pyramid

| Layer | Tool | Where they run | Speed budget |
|---|---|---|---|
| Unit (pure Kotlin) | JUnit5 + AssertK + Turbine + MockK | JVM | < 50ms each |
| ViewModel | JUnit5 + Turbine + `UnconfinedTestDispatcher` + fakes | JVM | < 100ms each |
| Repository / data | JUnit5 + Ktor `MockEngine` + in-memory Room | JVM | < 200ms each |
| Compose screen | ComposeTestRule, Robolectric or instrumented | JVM or device | < 1s each |
| End-to-end | Instrumented + UiAutomator | Device/emulator | sparingly |

## Framework choices

- JUnit5 (`org.junit.jupiter`) over JUnit4 for new modules. Old modules can stay JUnit4 until touched.
- AssertK over Hamcrest, AssertJ, Truth. One assertion library per repo.
- MockK over Mockito for Kotlin. Mockito only in legacy Java tests.
- Turbine for `Flow` assertions. Don't roll your own collector.
- Robolectric for Android-class unit tests that don't need a real device. Espresso only for instrumented integration tests.

## Patterns

- **Fakes over mocks** for repositories, data sources, and any collaborator with state. A fake is a real implementation backed by an in-memory store; it stays valid as the interface evolves.
- One ViewModel test class per `ViewModel`. One test per state transition.
- `runTest { ... }` with `UnconfinedTestDispatcher` for ViewModel tests. Inject the dispatcher; don't `Dispatchers.setMain` in every test.
- Test names: `` `returns Error when network fails during refresh` ``. Read like an English spec.
- AAA layout (Arrange / Act / Assert) with blank lines separating sections. No setup spread across 5 helpers.
- `SavedStateHandle` tests: rebuild the ViewModel with the same handle and assert state survives.

## What NOT to test

- Framework code. Don't test that `MutableStateFlow.value =` actually updates the value.
- Generated code (DataBinding, Hilt/Koin generated, Room generated DAO impls).
- UI pixel layout — visual regression tools (Paparazzi, Showkase) cover that, not unit tests.
- Private methods directly. Test through the public API.

## Compose UI tests

- `createComposeRule()` for screen-level tests in JVM (with Robolectric or Paparazzi).
- `createAndroidComposeRule<ComponentActivity>()` for instrumented.
- Use `onNodeWithTag` with stable tags from a `TestTags` object — not `onNodeWithText` for anything user-visible (breaks on translation).
- Assert against the ViewModel's `StateFlow` for state, against the tree for presence.

## Flaky tests

- Zero tolerance. A flaky test is quarantined within 24h and either fixed or deleted within the week.
- Never `@Ignore` without a linked ticket and an owner.
- No `Thread.sleep` in tests. Use coroutine test schedulers, `awaitItem()` (Turbine), or `composeTestRule.waitUntil`.

## CI

- Unit + Robolectric on every PR. Instrumented on `main` merges and release branches.
- Coverage report uploaded as PR comment. Drops > 1% block merge.
- `./gradlew check` is the single green-light command — it runs lint, ktlint, detekt, unit, Robolectric.

See also: [coding-style.md](coding-style.md), [git-workflow.md](git-workflow.md).
