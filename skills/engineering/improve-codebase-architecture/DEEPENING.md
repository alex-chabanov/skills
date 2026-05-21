# Deepening

How to deepen a cluster of shallow modules safely, given its dependencies. Assumes the vocabulary in [LANGUAGE.md](LANGUAGE.md) — **module**, **interface**, **seam**, **adapter**.

## Dependency categories

When assessing a candidate for deepening, classify its dependencies. The category determines how the deepened module is tested across its seam.

### 1. In-process

Pure computation, in-memory state, no I/O. Always deepenable — merge the modules and test through the new interface directly. No adapter needed.

### 2. Local-substitutable

Dependencies that have local test stand-ins (PGLite for Postgres, in-memory filesystem). Deepenable if the stand-in exists. The deepened module is tested with the stand-in running in the test suite. The seam is internal; no port at the module's external interface.

### 3. Remote but owned (Ports & Adapters)

Your own services across a network boundary (microservices, internal APIs). Define a **port** (interface) at the seam. The deep module owns the logic; the transport is injected as an **adapter**. Tests use an in-memory adapter. Production uses an HTTP/gRPC/queue adapter.

Recommendation shape: *"Define a port at the seam, implement an HTTP adapter for production and an in-memory adapter for testing, so the logic sits in one deep module even though it's deployed across a network."*

### 4. True external (Mock)

Third-party services (Stripe, Twilio, etc.) you don't control. The deepened module takes the external dependency as an injected port; tests provide a mock adapter.

### Android / Kotlin mapping

The same four categories, with Android dependencies slotted in:

| Category | Android example | How it's tested across the seam |
|---|---|---|
| In-process | reducer, mapper, `Result`-returning use case, validation | call the deep interface directly — no adapter |
| Local-substitutable | Room, DataStore | in-memory Room (`inMemoryDatabaseBuilder`), Robolectric — stand-in runs in the suite |
| Remote but owned | your backend over Ktor/Retrofit | repository is the deep module; inject a data-source port, `MockEngine`/in-memory adapter in tests, HTTP in prod |
| True external | Play Billing, FusedLocation, FCM, Maps SDK | inject a port at the seam; mock adapter in tests |

In an MVI codebase the repository **interface** is usually the load-bearing seam: the ViewModel and the use cases are the deep modules behind it, Koin binds the real adapter in production, and a fake binds in tests. A DAO or `HttpClient` exposed directly to a ViewModel is the shallow shape to deepen — pull it behind a repository so the logic gets locality and the seam gets two adapters (real + fake).

## Seam discipline

- **One adapter means a hypothetical seam. Two adapters means a real one.** Don't introduce a port unless at least two adapters are justified (typically production + test). A single-adapter seam is just indirection.
- **Internal seams vs external seams.** A deep module can have internal seams (private to its implementation, used by its own tests) as well as the external seam at its interface. Don't expose internal seams through the interface just because tests use them.

## Testing strategy: replace, don't layer

- Old unit tests on shallow modules become waste once tests at the deepened module's interface exist — delete them.
- Write new tests at the deepened module's interface. The **interface is the test surface**.
- Tests assert on observable outcomes through the interface, not internal state.
- Tests should survive internal refactors — they describe behaviour, not implementation. If a test has to change when the implementation changes, it's testing past the interface.
