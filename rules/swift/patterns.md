# Patterns — Swift / SwiftUI

Repeating shapes for API responses, errors, state, and navigation. Use these unmodified.

## API response wrapper

Network and repository functions return a typed `Result` so the error variant is exhaustive. Use `Swift.Result<T, DataError>` (the error type is a closed `enum`, so `switch` is exhaustive).

```swift
typealias EmptyResult = Result<Void, DataError>
```

### Error hierarchy

```swift
enum DataError: Error, Equatable {
    enum Network: Error, Equatable {
        case requestTimeout
        case tooManyRequests
        case noInternet
        case payloadTooLarge
        case serverError
        case serialization
        case unknown
    }

    enum Local: Error, Equatable {
        case diskFull
        case notFound
        case unknown
    }

    case network(Network)
    case local(Local)
}
```

### Helpers

`Swift.Result` already ships `map`, `mapError`, `get()`. Add only the success/failure side-effect helpers:

```swift
extension Result {
    @discardableResult
    func onSuccess(_ block: (Success) -> Void) -> Self {
        if case .success(let value) = self { block(value) }
        return self
    }

    @discardableResult
    func onFailure(_ block: (Failure) -> Void) -> Self {
        if case .failure(let error) = self { block(error) }
        return self
    }
}
```

### Rules

- Repositories return `Result<DomainModel, DataError>`. They never throw on expected failures (network down, 404, parse error) — they map them to a `DataError` case.
- Real programmer errors (force-unwrap of `nil`, precondition failure) crash. Don't `catch` to convert them to `.unknown`.
- View models map `DataError` → `UiText` before exposing to UI. The view never sees `DataError` directly.
- DTOs (`Codable` network/DB types) live in the data layer and are mapped to domain models at the repository boundary. No DTO leaks past the repository.

## Safe network call

```swift
func safeCall<T: Decodable>(
    _ execute: () async throws -> (Data, URLResponse)
) async -> Result<T, DataError.Network> {
    let data: Data
    let response: URLResponse
    do {
        (data, response) = try await execute()
    } catch is CancellationError {
        return .failure(.unknown)            // let structured cancellation propagate where it matters
    } catch let error as URLError {
        switch error.code {
        case .timedOut:                 return .failure(.requestTimeout)
        case .notConnectedToInternet,
             .networkConnectionLost:    return .failure(.noInternet)
        default:                        return .failure(.unknown)
        }
    } catch {
        return .failure(.unknown)
    }
    return responseToResult(data: data, response: response)
}
```

- Catch `CancellationError` explicitly so cooperative cancellation isn't masked as a network failure.
- One `safeCall` shared across the data layer. Don't re-implement per repository.
- Wrap only the throwing call (`execute()`), not the whole function body. Decoding, logging, and result construction stay outside the `do`.

## MVI / MVVM state, action, event

```swift
struct ProfileState: Equatable {
    var isLoading = false
    var name = ""
    var avatarURL: URL?
    var errorMessage: UiText?
}

enum ProfileAction: Equatable {
    case onRefresh
    case onNameChange(String)
    case onSave
}

enum ProfileEvent: Equatable {
    case navigateBack
    case showError(UiText)
}
```

- State: value type, `Equatable`, immutable from the view's side. One per screen.
- Action: every user intent — the view calls `viewModel.send(.onRefresh)`. No other public mutating methods on the view model.
- Event: one-shot side effects (navigation, alerts). Delivered via an `AsyncStream<ProfileEvent>` (or a `replay: 0` Combine subject) and consumed by the view with `.task { for await event in vm.events { … } }`.

```swift
@MainActor
@Observable
final class ProfileViewModel {
    private(set) var state = ProfileState()

    private let events = AsyncStream.makeStream(of: ProfileEvent.self)
    var eventStream: AsyncStream<ProfileEvent> { events.stream }

    func send(_ action: ProfileAction) { /* mutate state / emit events */ }
}
```

## UiText for strings

```swift
enum UiText: Equatable {
    case dynamic(String)
    case localized(LocalizedStringResource)

    var resolved: String {
        switch self {
        case .dynamic(let value):     return value
        case .localized(let resource): return String(localized: resource)
        }
    }
}
```

- View models emit `UiText`, not a raw user-facing `String`. Localization is resolved at the view.

## Pagination response

```swift
struct PagedResponse<T> {
    let items: [T]
    let nextCursor: String?
    let hasMore: Bool
}
```

- Cursor-based, not offset-based. Offsets break under concurrent writes.
- `hasMore` is explicit, not derived from `nextCursor == nil`. The server tells us.

## Navigation route

Type-safe `NavigationStack` with `Hashable` route values.

```swift
enum AppRoute: Hashable {
    case home
    case profile(userID: String)
}

NavigationStack(path: $path) {
    HomeScreen()
        .navigationDestination(for: AppRoute.self) { route in
            switch route {
            case .home:                    HomeScreen()
            case .profile(let userID):     ProfileScreen(userID: userID)
            }
        }
}
```

- One route enum per feature; the app module composes feature routes. Features don't know about other features' internals — cross-feature navigation goes through a coordinator closure.

See also: [coding-style.md](coding-style.md), [security.md](security.md).
