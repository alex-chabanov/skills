# Interface Design for Testability

Good interfaces make testing natural:

1. **Accept dependencies, don't create them**

   ```typescript
   // Testable
   function processOrder(order, paymentGateway) {}

   // Hard to test
   function processOrder(order) {
     const gateway = new StripeGateway();
   }
   ```

2. **Return results, don't produce side effects**

   ```typescript
   // Testable
   function calculateDiscount(cart): Discount {}

   // Hard to test
   function applyDiscount(cart): void {
     cart.total -= discount;
   }
   ```

3. **Small surface area**
   - Fewer methods = fewer tests needed
   - Fewer params = simpler test setup

## Android / Kotlin

Same three rules, MVI flavour:

```kotlin
// Testable: deps constructor-injected, state exposed as a value to read back
class NoteListViewModel(
    private val repo: NoteRepository,
    savedStateHandle: SavedStateHandle,
) : ViewModel() {
    val state: StateFlow<NoteListState>
}

// Hard to test: builds its own repo, leaks work as fire-and-forget side effects
class NoteListViewModel : ViewModel() {
    private val repo = NoteRepository(NoteDatabase.get().noteDao())
    fun refresh() { viewModelScope.launch { repo.sync() } }  // nothing to assert on
}
```

- **Accept dependencies** — constructor params, wired by Koin in prod and faked in tests. `SavedStateHandle` is injected the same way (construct it directly in tests).
- **Return results** — model outcomes in `state`/`events` so a test can read them back, rather than mutating external state invisibly.
- **Small surface** — one `onAction(action)` entry point over a sealed `Action` type beats a dozen public methods.
