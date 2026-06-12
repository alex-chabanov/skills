# Testing — Swift / SwiftUI

## TDD baseline

- Red → green → refactor. Write the failing test first for any new behavior, bug fix, or regression.
- A bug report becomes a failing test before the fix lands. The test stays.
- Refactors do not need new tests, but must keep the existing suite green.

## Coverage targets

- Project-wide line coverage: **≥ 80%**. CI fails below threshold.
- `Core*` packages (no UIKit/SwiftUI dependency): **≥ 90%** — pure Swift, no excuse.
- View models: **100% of state transitions and event emissions**. Coverage alone is not enough — assert state sequences.
- SwiftUI views: smoke + critical-path UI tests, not coverage-driven.
- Exclude from coverage: generated code, DI wiring, `App`/`AppDelegate`, asset/resource accessors. Declare exclusions in the coverage config, not by deleting tests.

## Test pyramid

| Layer | Tool | Where they run | Speed budget |
|---|---|---|---|
| Unit (pure Swift) | Swift Testing (or XCTest) | Simulator/macOS | < 50ms each |
| View model | Swift Testing + async expectations + fakes | Simulator/macOS | < 100ms each |
| Repository / data | XCTest + `URLProtocol` stub + in-memory store | Simulator/macOS | < 200ms each |
| SwiftUI view | ViewInspector / snapshot (Paparazzi-equivalent) | Simulator | < 1s each |
| End-to-end | XCUITest | Simulator/device | sparingly |

## Framework choices

- Swift Testing (`import Testing`, `@Test`, `#expect`) for new test targets. XCTest stays for existing targets until touched.
- One assertion style per repo. With Swift Testing use `#expect`/`#require`; with XCTest use `XCTAssert*` — don't mix a third-party matcher library in.
- Prefer protocol-backed fakes over mocking frameworks. If a mocking lib is already in use, keep it confined to legacy targets.
- For async `AsyncSequence`/stream assertions, collect with a bounded helper (`for await … { } / break`) — don't roll an ad-hoc sleep-and-poll.

## Patterns

- **Fakes over mocks** for repositories, data sources, and any collaborator with state. A fake is a real in-memory implementation; it stays valid as the protocol evolves.
- One test type per view model. One test per state transition.
- `await` the async API under test; drive time with injected clocks (`Clock`/`ContinuousClock` or a test clock) — never `Task.sleep` real time in a test.
- Test names read like a spec: `test_returnsError_whenNetworkFailsDuringRefresh()` or `@Test("returns error when network fails during refresh")`.
- AAA layout (Arrange / Act / Assert) with blank lines separating sections. No setup spread across 5 helpers.
- State-restoration tests: rebuild the view model from the same persisted state (`@SceneStorage`/serialized snapshot) and assert state survives.

## What NOT to test

- Framework code. Don't test that assigning to `@State` updates the value, or that `URLSession` works.
- Generated code (SwiftData/Core Data generated accessors, `Codable` synthesized conformances, DI-generated wiring).
- UI pixel layout — snapshot tools cover that, not unit tests.
- `private` methods directly. Test through the public API.

## SwiftUI UI tests

- ViewInspector or snapshot tests for view-level logic in the simulator; reserve XCUITest for true end-to-end flows.
- Drive selection by stable accessibility identifiers from a `TestTags` namespace — not by visible text (breaks on localization).
- Assert state against the view model's observable state; assert presence against the view tree.

## Flaky tests

- Zero tolerance. A flaky test is quarantined within 24h and either fixed or deleted within the week.
- Never `.disabled`/skip without a linked ticket and an owner.
- No real-time sleeps. Use injected clocks, async expectations, or `XCUIElement.waitForExistence(timeout:)`.

## CI

- Unit + view-model + snapshot on every PR. XCUITest on `main` merges and release branches.
- Coverage report posted as a PR comment. Drops > 1% block merge.
- A single green-light command runs lint + format-check + unit + UI: `swift test` for packages, `xcodebuild test` for the app scheme.

See also: [coding-style.md](coding-style.md), [git-workflow.md](git-workflow.md).
