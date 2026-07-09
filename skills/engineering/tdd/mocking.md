# When to Mock

Mock at **system boundaries** only:

- External APIs (payment, email, etc.)
- Databases (sometimes - prefer test DB)
- Time/randomness
- File system (sometimes)

Don't mock:

- Your own classes/modules
- Internal collaborators
- Anything you control

## Designing for Mockability

At system boundaries, design interfaces that are easy to mock:

**1. Use dependency injection**

Pass external dependencies in rather than creating them internally:

```kotlin
// Easy to fake
suspend fun processPayment(order: Order, payments: PaymentClient) =
    payments.charge(order.total)

// Hard to fake — the client is built internally, no seam
suspend fun processPayment(order: Order) =
    StripeClient(BuildConfig.STRIPE_KEY).charge(order.total)
```

**2. Prefer SDK-style interfaces over generic fetchers**

Declare one operation per external call instead of a single generic entry point with conditional logic:

```kotlin
// GOOD: Each operation is independently fakeable
interface OrderApi {
    suspend fun getUser(id: UserId): User
    suspend fun getOrders(userId: UserId): List<Order>
    suspend fun createOrder(draft: OrderDraft): Order
}

// BAD: Faking requires conditional logic inside the fake
interface OrderApi {
    suspend fun request(endpoint: String, body: Any?): HttpResponse
}
```

The SDK approach means:
- Each fake returns one specific shape
- No conditional logic in test setup
- Easier to see which endpoints a test exercises
- Type safety per endpoint

## Android / Kotlin

**Prefer fakes over mocks.** A `FakeNoteRepository : NoteRepository` backed by an in-memory `MutableList` catches more real bugs than `mockk` and survives refactors — it satisfies the same interface the real one does. Reach for `mockk`/`coVerify` only at true externals you don't own.

The Android boundary map:

- **Repository / data source** → fake. It's yours; the interface already exists for DI.
- **Room** → in-memory DB (`Room.inMemoryDatabaseBuilder(...)`), Robolectric or instrumented. Don't mock the DAO.
- **Ktor `HttpClient`** → swap `MockEngine` in, assert through the repository. Don't mock the client object.
- **System SDKs you don't control** (Play Billing, FusedLocation, FCM) → mock at the injected port.

Inject dependencies through the constructor so tests pass fakes and Koin wires the real adapters in production:

```kotlin
// Easy to fake — Koin provides the real repo in prod, tests pass FakeNoteRepository
class NoteListViewModel(private val repo: NoteRepository) : ViewModel()

// Hard to fake — repo built internally, no seam
class NoteListViewModel : ViewModel() {
    private val repo = NoteRepository(NoteDatabase.get().noteDao())
}
```

## Apple / Swift

**Prefer fakes over mocks.** Swift has no runtime mocking framework worth reaching for — a `FakeNoteRepository` conforming to the same protocol as the real one is both the idiomatic and the better choice. Reach for a spy only at true externals you don't own.

The Apple boundary map:

- **Repository / data source** → fake conforming to the protocol. It's yours; the protocol already exists for injection.
- **Core Data / SwiftData** → in-memory store (`NSPersistentContainer` with `/dev/null` URL, or `ModelConfiguration(isStoredInMemoryOnly: true)`). Don't fake the context.
- **`URLSession`** → inject a `URLProtocol` stub, assert through the repository. Don't fake `URLSession` itself.
- **System frameworks you don't control** (StoreKit, CoreLocation, UserNotifications) → fake at the injected protocol, not the framework type.

Inject dependencies through the initializer so tests pass fakes and the composition root wires real adapters in production:

```swift
// Easy to fake — the app composes the real repo; tests pass FakeNoteRepository
@MainActor final class NoteListViewModel {
    private let repository: NoteRepository
    init(repository: NoteRepository) { self.repository = repository }
}

// Hard to fake — repo built internally, no seam
@MainActor final class NoteListViewModel {
    private let repository = LiveNoteRepository(context: PersistenceController.shared.context)
}
```
