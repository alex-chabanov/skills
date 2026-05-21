# Good and Bad Tests

## Good Tests

**Integration-style**: Test through real interfaces, not mocks of internal parts.

```typescript
// GOOD: Tests observable behavior
test("user can checkout with valid cart", async () => {
  const cart = createCart();
  cart.add(product);
  const result = await checkout(cart, paymentMethod);
  expect(result.status).toBe("confirmed");
});
```

Characteristics:

- Tests behavior users/callers care about
- Uses public API only
- Survives internal refactors
- Describes WHAT, not HOW
- One logical assertion per test

## Bad Tests

**Implementation-detail tests**: Coupled to internal structure.

```typescript
// BAD: Tests implementation details
test("checkout calls paymentService.process", async () => {
  const mockPayment = jest.mock(paymentService);
  await checkout(cart, payment);
  expect(mockPayment.process).toHaveBeenCalledWith(cart.total);
});
```

Red flags:

- Mocking internal collaborators
- Testing private methods
- Asserting on call counts/order
- Test breaks when refactoring without behavior change
- Test name describes HOW not WHAT
- Verifying through external means instead of interface

```typescript
// BAD: Bypasses interface to verify
test("createUser saves to database", async () => {
  await createUser({ name: "Alice" });
  const row = await db.query("SELECT * FROM users WHERE name = ?", ["Alice"]);
  expect(row).toBeDefined();
});

// GOOD: Verifies through interface
test("createUser makes user retrievable", async () => {
  const user = await createUser({ name: "Alice" });
  const retrieved = await getUser(user.id);
  expect(retrieved.name).toBe("Alice");
});
```

## Android / Kotlin

Same principle: test the ViewModel through its `state`/`events`, not its private fields. Use Turbine for flows, AssertK for assertions, a **fake** repository for the dependency. `Dispatchers.setMain(UnconfinedTestDispatcher())` in `@BeforeEach`.

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
