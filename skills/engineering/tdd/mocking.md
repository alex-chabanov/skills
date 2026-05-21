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

```typescript
// Easy to mock
function processPayment(order, paymentClient) {
  return paymentClient.charge(order.total);
}

// Hard to mock
function processPayment(order) {
  const client = new StripeClient(process.env.STRIPE_KEY);
  return client.charge(order.total);
}
```

**2. Prefer SDK-style interfaces over generic fetchers**

Create specific functions for each external operation instead of one generic function with conditional logic:

```typescript
// GOOD: Each function is independently mockable
const api = {
  getUser: (id) => fetch(`/users/${id}`),
  getOrders: (userId) => fetch(`/users/${userId}/orders`),
  createOrder: (data) => fetch('/orders', { method: 'POST', body: data }),
};

// BAD: Mocking requires conditional logic inside the mock
const api = {
  fetch: (endpoint, options) => fetch(endpoint, options),
};
```

The SDK approach means:
- Each mock returns one specific shape
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
