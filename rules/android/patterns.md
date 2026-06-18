# Patterns — Android (Java/Kotlin)

Repeating shapes for API responses, errors, state, and navigation. Use these unmodified.

## API response wrapper

Network and repository functions return `Result<T, DataError>` (not `kotlin.Result` — a typed sealed `Result` so the error variant is exhaustive).

```kotlin
sealed interface Result<out D, out E : RootError> {
    data class Success<out D, out E : RootError>(val data: D) : Result<D, E>
    data class Error<out D, out E : RootError>(val error: E) : Result<D, E>
}

typealias EmptyResult<E> = Result<Unit, E>
```

### Error hierarchy

```kotlin
sealed interface RootError

sealed interface DataError : RootError {
    enum class Network : DataError {
        REQUEST_TIMEOUT,
        TOO_MANY_REQUESTS,
        NO_INTERNET,
        PAYLOAD_TOO_LARGE,
        SERVER_ERROR,
        SERIALIZATION,
        UNKNOWN,
    }

    enum class Local : DataError {
        DISK_FULL,
        NOT_FOUND,
        UNKNOWN,
    }
}
```

### Helpers

```kotlin
inline fun <T, E : RootError, R> Result<T, E>.map(transform: (T) -> R): Result<R, E> =
    when (this) {
        is Result.Success -> Result.Success(transform(data))
        is Result.Error -> Result.Error(error)
    }

inline fun <T, E : RootError> Result<T, E>.onSuccess(block: (T) -> Unit): Result<T, E> {
    if (this is Result.Success) block(data)
    return this
}

inline fun <T, E : RootError> Result<T, E>.onFailure(block: (E) -> Unit): Result<T, E> {
    if (this is Result.Error) block(error)
    return this
}
```

### Rules

- Repositories return `Result<DomainModel, DataError>`. They never throw on expected failures (network down, 404, parse error).
- Real exceptions (programmer error: NPE, IllegalState) propagate. Don't `try/catch` to convert them to `DataError.UNKNOWN`.
- ViewModels map `DataError` → `UiText` before exposing to UI. UI never sees `DataError` directly.
- DTOs (network/db) live in the data layer and are mapped to domain models at the repository boundary. No DTO leaks past the repository.

## Safe network call

```kotlin
suspend inline fun <reified T> safeCall(execute: () -> HttpResponse): Result<T, DataError.Network> {
    val response = try {
        execute()
    } catch (e: SocketTimeoutException) {
        return Result.Error(DataError.Network.REQUEST_TIMEOUT)
    } catch (e: UnknownHostException) {
        return Result.Error(DataError.Network.NO_INTERNET)
    } catch (e: SerializationException) {
        return Result.Error(DataError.Network.SERIALIZATION)
    } catch (e: Exception) {
        coroutineContext.ensureActive()
        return Result.Error(DataError.Network.UNKNOWN)
    }
    return responseToResult(response)
}
```

- `coroutineContext.ensureActive()` in the catch-all so cancellation isn't swallowed.
- One `safeCall` shared across the data layer. Don't re-implement per repository.
- Wrap only the call that can throw (`execute()`), not the whole function body. Mapping, logging, and result construction stay outside the `try`.

## MVI state / action / event

```kotlin
data class ProfileState(
    val isLoading: Boolean = false,
    val name: String = "",
    val avatarUrl: String? = null,
    val errorMessage: UiText? = null,
)

sealed interface ProfileAction {
    data object OnRefresh : ProfileAction
    data class OnNameChange(val value: String) : ProfileAction
    data object OnSave : ProfileAction
}

sealed interface ProfileEvent {
    data object NavigateBack : ProfileEvent
    data class ShowError(val message: UiText) : ProfileEvent
}
```

- State: serializable, immutable, `data class`. One per screen.
- Action: every user intent — UI calls `viewModel.onAction(...)`. No other public methods on the ViewModel.
- Event: one-shot side effects (navigation, snackbars). Emitted via `Channel(BUFFERED).receiveAsFlow()`. Collected with `ObserveAsEvents` to respect lifecycle.
- Screen params (Intent extras, nav args): the ViewModel extracts them from `SavedStateHandle` — not the Activity reading the `Intent` and hand-passing them in. The framework injects extras into `SavedStateHandle`, so it's the source of truth: survives process death without manual save/restore, keeps the Activity a dumb host, and is unit-testable via `SavedStateHandle(mapOf(...))`. The ViewModel must never reference `android.content.Intent` (`SavedStateHandle` is platform-agnostic, so it's fine).
- State survival — ask this for **every** mutable ViewModel field before declaring it: *must this value survive process death?* A plain `MutableStateFlow` (or `private var`) survives configuration change (rotation) but is **lost** when the system kills a backgrounded app and the user returns. Don't default to `MutableStateFlow` without answering the question.
  - Yes, must survive death, **and** it's small, Bundle-able, and can't be reloaded/re-derived (selected filter, search query, in-progress form field) → back it with `SavedStateHandle`. `SavedStateHandle` writes through a `Bundle`, so only Bundle-able types survive (primitives, `String`, `Parcelable`/`@Parcelize`, `Serializable`, arrays/`ArrayList` of those) and total size must stay small (~1 MB binder limit → `TransactionTooLargeException`). Non-Parcelable domain object → make it `@Parcelize` or store a key and rehydrate. Big blob → reload from repo, don't stash.

    ```kotlin
    // ❌ lost on process death
    private val _selectedKeyword = MutableStateFlow<String?>(null)

    // ✅ survives process death, still a StateFlow
    val selectedKeyword = savedStateHandle.getStateFlow<String?>("selectedKeyword", null)
    fun onKeywordSelected(value: String?) { savedStateHandle["selectedKeyword"] = value }
    ```

  - No — it's a screen param, reloadable from a repo, or cheaply re-derivable → plain `MutableStateFlow`; reload or re-extract on recreation.
  - Caveat: if a value vanishes on **rotation** (not just process death), that's a ViewModel **scoping bug** (hand-constructed VM, wrong owner, `remember { VM() }`) — fix the wiring; `SavedStateHandle` would only mask it.

## UiText for strings

```kotlin
sealed interface UiText {
    data class Dynamic(val value: String) : UiText
    class StringResource(@StringRes val id: Int, vararg val args: Any) : UiText

    @Composable
    fun asString(): String = when (this) {
        is Dynamic -> value
        is StringResource -> stringResource(id, *args)
    }
}
```

- ViewModels emit `UiText`, not raw `String`. Resource resolution happens in the composable.

## Pagination response

```kotlin
data class PagedResponse<T>(
    val items: List<T>,
    val nextCursor: String?,
    val hasMore: Boolean,
)
```

- Cursor-based, not offset-based. Offsets break under concurrent writes.
- `hasMore` is explicit, not derived from `nextCursor == null`. The server tells us.

## Navigation route

Type-safe Compose Navigation. Routes are `@Serializable` data classes/objects.

```kotlin
@Serializable
data object HomeRoute

@Serializable
data class ProfileRoute(val userId: String)
```

- One file per feature: `<Feature>NavGraph.kt` with a `NavGraphBuilder.<feature>Graph(...)` extension.
- App module composes the feature graphs. Features don't know about other features.

See also: [coding-style.md](coding-style.md), [security.md](security.md).
