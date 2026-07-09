# Good and Bad Tests

## Good Tests

**Integration-style**: Test through real interfaces, not mocks of internal parts.

```kotlin
// GOOD: Tests observable behavior
@Test
fun `user can checkout with valid cart`() = runTest {
    val cart = createCart()
    cart.add(product)
    val result = checkout(cart, paymentMethod)
    assertThat(result.status).isEqualTo(OrderStatus.Confirmed)
}
```

Characteristics:

- Tests behavior users/callers care about
- Uses public API only
- Survives internal refactors
- Describes WHAT, not HOW
- One logical assertion per test

## Bad Tests

**Implementation-detail tests**: Coupled to internal structure.

```kotlin
// BAD: Tests implementation details
@Test
fun `checkout calls paymentService process`() = runTest {
    val payments = mockk<PaymentService>(relaxed = true)
    checkout(cart, payments)
    coVerify { payments.process(cart.total) }
}
```

Red flags:

- Mocking internal collaborators
- Testing private methods
- Asserting on call counts/order
- Test breaks when refactoring without behavior change
- Test name describes HOW not WHAT
- Verifying through external means instead of interface

```kotlin
// BAD: Bypasses interface to verify
@Test
fun `createUser saves to database`() = runTest {
    createUser(name = "Alice")
    val row = db.query("SELECT * FROM users WHERE name = ?", "Alice")
    assertThat(row).isNotNull()
}

// GOOD: Verifies through interface
@Test
fun `createUser makes user retrievable`() = runTest {
    val user = createUser(name = "Alice")
    assertThat(getUser(user.id).name).isEqualTo("Alice")
}
```

**Tautological tests**: Expected value restates the implementation, so the test passes by construction.

```kotlin
// BAD: Expected value is recomputed the way the code computes it
@Test
fun `calculateTotal sums line items`() {
    val items = listOf(LineItem(price = 10), LineItem(price = 5))
    val expected = items.sumOf { it.price }
    assertThat(calculateTotal(items)).isEqualTo(expected)
}

// GOOD: Expected value is an independent, known literal
@Test
fun `calculateTotal sums line items`() {
    assertThat(calculateTotal(listOf(LineItem(price = 10), LineItem(price = 5)))).isEqualTo(15)
}
```

## Android / Kotlin

Test the ViewModel through its `state`/`events`, not its private fields. Use Turbine for flows, AssertK for assertions, a **fake** repository for the dependency. `Dispatchers.setMain(UnconfinedTestDispatcher())` in `@BeforeEach`.

```kotlin
// GOOD: behaviour through the public state flow
@Test
fun `refresh loads notes into state`() = runTest {
    val viewModel = NoteListViewModel(FakeNoteRepository())
    viewModel.state.test {
        viewModel.onAction(NoteListAction.OnRefreshClick)
        assertThat(awaitItem().isLoading).isTrue()
        assertThat(awaitItem().notes).isNotEmpty()
    }
}
```

```kotlin
// BAD: reaches past the interface to the DAO, and mocks an internal collaborator
@Test
fun `refresh calls dao insert`() = runTest {
    val dao = mockk<NoteDao>(relaxed = true)
    NoteListViewModel(NoteRepository(dao)).onAction(NoteListAction.OnRefreshClick)
    coVerify { dao.insert(any()) }   // breaks on any internal refactor
}
```

Red flags map directly: asserting on `viewModel.someInternalField`, verifying a DAO/`HttpClient` call count, or querying Room directly instead of reading it back through the repository.

## Apple / Swift

Same principle with Swift Testing: assert on the observable output of the type under test, and let a fake satisfy the dependency's protocol.

```swift
// GOOD: behaviour through the observable interface
@Test func refreshLoadsNotesIntoState() async throws {
    let viewModel = NoteListViewModel(repository: FakeNoteRepository())
    await viewModel.refresh()
    #expect(viewModel.state.isLoading == false)
    #expect(viewModel.state.notes.isEmpty == false)
}
```

```swift
// BAD: asserts on a spy's call record, and reaches past the interface into the store
@Test func refreshCallsStoreInsert() async throws {
    let store = SpyNoteStore()
    await NoteListViewModel(repository: NoteRepository(store: store)).refresh()
    #expect(store.insertCallCount == 1)   // breaks on any internal refactor
}
```

Red flags map directly: asserting on a `private(set)` field the view never reads, counting `URLSession`/`NSManagedObjectContext` calls, or fetching from Core Data directly instead of reading back through the repository.
