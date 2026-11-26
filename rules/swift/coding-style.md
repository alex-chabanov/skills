# Coding style — Swift / SwiftUI

## Attitude to existing code

- **Do not mimic existing patterns just for consistency.** Follow this spec; old code is not authoritative.
- When you modify a file, refactor the parts you touch to this spec. Don't perpetuate smells (God object, deep nesting, hardcoded values, tight coupling) "to match surroundings".
- Behavior must stay unchanged during a refactor. Tests prove it.
- If the refactor cascades across **more than 3 files**, stop and explain the plan before continuing — let the user choose scope.
- Deleting dead code is part of touching code. No commented-out blocks left behind.

## Language defaults

- Swift for all new code. Objective-C only when touching existing `.m`/`.h` files or interop boundaries.
- Target the project's lowest supported deployment target; gate newer APIs with `@available` / `#available`, never raise the floor silently.
- Treat warnings as errors (`SWIFT_TREAT_WARNINGS_AS_ERRORS = YES`). No `// swiftlint:disable` without a `// reason:` comment on the same line.

## Immutability

- `let` over `var`. A `var` in a function body needs justification; a `var` at type scope needs a comment.
- `struct` for state. No reference-type aliasing of value state — mutate a local copy and reassign.
- Collections exposed on public API are `let` properties typed as the read-only protocol need (`some Sequence`, `[T]` returned by value). Mutate locally, expose immutable.
- SwiftUI state: `@State private`, never expose mutable bindings up the tree. View models expose a read-only observable state value (`private(set)` on `@Observable` properties or a computed `UiState` struct). Never hand a `Binding` to a child that should be read-only.
- DTOs, domain models, `Codable` types: all `let` properties.

## Optionals & nullability

- Prefer non-optional types. `?` is a deliberate signal, not laziness.
- Never force-unwrap (`!`) outside test code. Replace with `guard let … else`, `if let`, `??` with a meaningful default, or `?? preconditionFailure("reason")` so failures are explained.
- Never force-try (`try!`) or force-cast (`as!`) in production code. Use `try?`, typed `do/catch`, or `guard case`.
- Implicitly-unwrapped optionals (`T!`) are banned outside `@IBOutlet` and the narrow Interface Builder lifecycle.
- Use `Result<T, Error>` or a custom `enum` for fallible operations; do not return `nil` to mean "failure" when the failure has a reason worth naming.

## File size limits

- Hard cap: **500 lines per file**. At 400 lines, start planning the split.
- Hard cap: **40 lines per function/computed property**. A `body` that exceeds 40 lines must be decomposed into smaller subviews or `@ViewBuilder` slots.
- Hard cap: **5 parameters per function**. More than 5 → introduce a parameter `struct`.
- Hard cap: **3 levels of nesting** inside a function. Use early `guard` returns, `map`/`compactMap`, or extract.
- Type fan-out: a single type with more than 7 collaborators is a smell — extract a coordinator.

## Naming

- Modules / package targets: `UpperCamelCase` (`FeatureProfile`, `CoreNetworking`).
- Types, protocols: `UpperCamelCase`. Views: `UpperCamelCase`; full-screen destinations end in `Screen` (`ProfileScreen`), reusable components end in `View` (`AvatarView`).
- Functions, vars, cases: `lowerCamelCase`. Constants: `lowerCamelCase` (Swift convention — no `UPPER_SNAKE`), grouped in a `enum` namespace or `static let`.
- Booleans read as questions: `isLoading`, `hasError`, `canSubmit`. Not `loading`, `error`, `submit`.
- Action methods prefixed `handle`: `handleTap`, `handleSubmit`, `handleRefresh`. Closure parameters on views prefixed `on`: `onTap`, `onSubmit` (the param shape; the implementation method uses `handle`).
- No meaningless names: `data1`, `temp`, `info`, `obj`, `result`, `item` (loop var exception allowed for `item` inside a 3-line block).
- Test functions: descriptive sentences — `func test_returnsLoadingThenSuccess_whenRefreshSucceeds()`, or with Swift Testing: `@Test("returns loading then success when refresh succeeds")`.
- Follow the Swift API Design Guidelines: omit needless words, name by role, prefer fluent call sites that read as English.

## Constants & magic values

- No magic numbers, no magic strings. Extract to a `static let` inside a namespacing `enum` with a semantic name.
  - `try await Task.sleep(for: .milliseconds(300))` behind `static let debounce: Duration = .milliseconds(300)`
  - `if status == 401` → `if status == HTTPStatus.unauthorized.rawValue`.
- Single-use constants are still constants. The name carries intent the literal cannot.
- Exception: 0, 1, -1, true, false in obvious contexts (`array.count - 1`, `index == 0`).
- No commented-out code. Delete it. Git remembers.

## Composition & boundaries

- Composition over inheritance. Prefer `struct` + protocols over class hierarchies. Use class inheritance only where the framework forces it (`UIViewController`, `NSObject` subclasses).
- Program to protocols at module boundaries. `Feature*` targets depend on `Core*` **protocols**, not concrete types. Concretes are injected.
- Unidirectional dependencies: `App → Feature → Domain → Data`. Lower layers never import upper layers. Enforce with Swift Package target boundaries and an import-lint check in CI.
- One designated initializer per type that establishes a valid state. Convenience initializers only delegate.
- Never instantiate collaborators inside an initializer. Receive them as init arguments (DI) or via a factory. SwiftUI exception: a `View` takes state + closures, not service objects — services reach the view model, not the view.
- Wrap primitives in a single-field `struct` (or `enum` raw value) when type confusion or invariants matter — IDs, monetary amounts, durations, units. Don't wrap speculatively: a raw `Int`/`String` for a field with no invariant is fine.
  ```swift
  struct UserID: Hashable { let value: String }
  struct Cents: Hashable { let value: Int64 }
  ```
- Command/query separation: a method either **returns a meaningful value** (query, no observable side effect) or **performs a single action** (command, returns `Void`). Not both.
- Types validate their own invariants in their initializer (make it `throws` or failable). Callers do not re-validate. Pair with "validate at system boundaries" below — boundary code constructs the validated type once; everything downstream trusts it.

## Events vs direct calls

- Direct method calls inside a feature module. They trace cleanly through a stack.
- Events (a one-shot `AsyncStream`/`PassthroughSubject` of `Event` cases, see [patterns.md](patterns.md)) for **cross-feature notification**, navigation requests, and one-shot UI side effects (alert, toast, sheet).
- Don't promote everything to an event bus. Loose coupling has a debugging cost — pay it only where it buys real decoupling.

## Validation boundaries

- Validate at system boundaries only: user input, network responses, file I/O, URL-scheme / universal-link parameters, push payloads.
- Internal calls trust their parameter types. No re-checking a non-optional Swift param, no re-checking a `String` is non-empty after the validating layer.
- Error messages name the failing operation and relevant values: `"refresh failed for userID=\(userID), status=\(status)"`, not `"error occurred"`. Don't include secrets.
- Don't wrap whole function bodies in `do/catch`. Wrap the specific call that can throw. See [patterns.md](patterns.md) for the `safeCall` shape.

## Swift idioms

- Prefer `switch` over chained `if/else if`. Exhaustive `switch` on `enum` — no `default` branch when the cases are known and closed.
- Use `guard` for early exit; keep the happy path unindented.
- Extensions for cohesive helpers and protocol conformances, one concern per extension. Not for hiding mutation.
- Concurrency: structured concurrency only. `async`/`await`, `async let`, `TaskGroup`. Isolate shared mutable state in an `actor`. UI state types are `@MainActor`.
- Never spawn an unstructured `Task {}` whose lifetime outlives the owning view/view model without storing and cancelling it. No detached tasks for routine work.
- `@Observable` (Observation framework) for state. `ObservableObject`/`@Published` only in legacy code. To observe `@Observable` changes outside SwiftUI, use the [`Observations`](https://developer.apple.com/documentation/observation/observations) async sequence (iOS 26+), not Combine. `AsyncStream` for event streams; Combine only where an existing API forces it.
- `async` functions must be main-safe or document the executor/actor they require.
- New targets use the [Swift 6 language mode](https://developer.apple.com/documentation/swift/adoptingswift6) with complete concurrency checking. App/UI targets keep Xcode 26's defaults: Default Actor Isolation `MainActor` ([SE-0466](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0466-control-default-actor-isolation.md)) and Approachable Concurrency on. `Core*` library packages keep `nonisolated` default isolation.

## Objective-C (when unavoidable)

- Annotate nullability (`NS_ASSUME_NONNULL_BEGIN`/`_nullable`) on every header.
- `NSArray`/`NSDictionary` with lightweight generics (`NSArray<NSString *> *`). No untyped collections.
- Bridge to Swift with `NS_SWIFT_NAME` where the auto-generated name reads poorly.

## SwiftUI-specific

- Hoist state. Views that own state are leaves; container views pass state down and closures up.
- Pass closures for events: `onTap: () -> Void`. Don't pass a whole view model into a deep child — pass the slice it needs.
- `@State` for view-local state, `@SceneStorage`/`@AppStorage` across launches where appropriate, view-model observable state for anything surviving navigation.
- Keep view params `Equatable`/value types so SwiftUI can skip re-evaluating `body`. Wrap reference types behind an `Equatable` wrapper or `@Observable`.
- Side effects belong in `.task {}`, `.onAppear`, `.onChange(of:initial:_:)` (the zero- or two-parameter closure form; single-parameter [`onChange(of:perform:)`](https://developer.apple.com/documentation/swiftui/view/onchange(of:perform:)) is deprecated), or `.refreshable`. Never start async work inline in `body`.

## Formatting

- A formatter (SwiftFormat, or [`swift format`](https://github.com/swiftlang/swift-format) from the Xcode 16+ toolchain) plus SwiftLint, configured and run in CI. CI fails on violations.
- 4-space indent. Trailing commas on multi-line literals. One type per file unless tightly cohesive (an `enum` hierarchy + its small helpers).

## Comments

- Default: no comment. Code explains itself.
- Write a comment only for **why** that isn't obvious: a workaround for a framework bug, a non-obvious invariant, a perf trade-off. Link to issue/PR/radar/docs when relevant.
- DocC (`///`) on the public API of `Core*` packages; internal feature code does not need doc comments on every function.

## Apple-maintained references

Apple keeps these skills (Xcode integration plugin) current with each SDK. Consult them for API-level detail instead of growing this file:

- SwiftUI API choice, Observation, `@Entry`, `ForEach` identity, soft-deprecated APIs: `xcode-integration:swiftui-specialist`.
- New SwiftUI APIs in the current SDK: `xcode-integration:swiftui-whats-new-<year>` (the suffix tracks the SDK year, e.g. `-27`).
- App Intents: `xcode-integration:app-intents-specialist`, `xcode-integration:app-intents-whats-new-<year>`.
- Resizable windows and multitasking: `xcode-integration:app-resizability`.
- Accessibility audits: `xcode-integration:accessibility-voiceover-specialist`, `-dynamic-type-specialist`, `-sufficient-contrast-specialist`.

On an API detail, the skill wins over this file. On architecture, naming, and project conventions, this file wins.

See also: [testing.md](testing.md), [patterns.md](patterns.md).

_Last verified against developer.apple.com: 2026-11-26 (iOS 27 SDK, Swift 6.2). Linked claims are re-checked by the scheduled rules review._
