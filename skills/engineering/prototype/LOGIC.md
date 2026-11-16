# Logic Prototype

A tiny interactive terminal app that lets the user drive a state model by hand. Use this when the question is about **business logic, state transitions, or data shape**: the kind of thing that looks reasonable on paper but only feels wrong once you push it through real cases.

## When this is the right shape

- "I'm not sure if this state machine handles the edge case where X then Y."
- "Does this data model actually let me represent the case where..."
- "I want to feel out what the API should look like before writing it."
- Anything where the user wants to **press buttons and watch state change**.

If the question is "what should this look like," this is the wrong branch. Use [UI.md](UI.md).

## Process

### 1. State the question

Before writing code, write down what state model and what question you're prototyping. One paragraph, in the prototype's README or a comment at the top of the file. A logic prototype that answers the wrong question is pure waste, so make the question explicit so it can be checked later, whether the user is watching now or returning to it AFK.

### 2. Pick the language

Use whatever the host project uses. If the project has no obvious runtime (e.g. a docs repo), ask.

Match the project's existing conventions for tooling. Don't add a new package manager or runtime just for the prototype.

### 3. Isolate the logic in a portable module

Put the actual logic (the bit that's answering the question) behind a small, pure interface that could be lifted out and dropped into the real codebase later. The TUI around it is throwaway; the logic module isn't.

The right shape depends on the question:

- **A pure reducer**: `(state, action) -> state`. Good when actions are discrete events and state is a single value.
- **A state machine**: explicit states and transitions. Good when "which actions are even legal right now" is part of the question.
- **A small set of pure functions** over a plain data type. Good when there's no implicit current state, just transformations.
- **A class or module with a clear method surface** when the logic genuinely owns ongoing internal state.

Pick whichever shape best fits the question being asked, *not* whichever is easiest to wire to a TUI. Keep it pure: no I/O, no terminal code, no `println` for control flow. The TUI calls into it; nothing flows the other direction.

This is what makes the prototype useful past its own lifetime: once the question's answered, the validated reducer / machine / function set lifts into the real module on its own.

### 4. Build the smallest TUI that exposes the state

Build it as a **lightweight TUI**: on every tick, clear the screen (`print("\u001b[2J\u001b[H")` or equivalent) and re-render the whole frame. The user should always see one stable view, not an ever-growing scrollback.

Each frame has two parts, in this order:

1. **Current state**, pretty-printed and diff-friendly (one field per line). Use **bold** for field names or section headers and **dim** for less important context (timestamps, IDs, derived values). Native ANSI escape codes are fine (`\u001b[1m` bold, `\u001b[2m` dim, `\u001b[0m` reset); no need to pull in a styling library unless one is already in the project.
2. **Keyboard shortcuts**, listed at the bottom: `[a] add user  [d] delete user  [t] tick clock  [q] quit`. Bold the key, dim the description, or vice-versa, whatever reads cleanly.

Behaviour:

1. **Initialise state**: a single in-memory object/struct. Render the first frame on start.
2. **Read one keystroke (or one line)** at a time, dispatch to a handler that updates state.
3. **Re-render** the full frame after every action: replace, don't append.
4. **Loop until quit.**

The whole frame should fit on one screen.

### 5. Make it runnable in one command

Add an entry to the project's existing task runner (a Gradle task, a `Package.swift` executable target, `Makefile`, `justfile`). The user should run `./gradlew :prototype:run`, `swift run <prototype-name>`, or equivalent, and never need to remember a path.

If the host project has no task runner, put the command at the top of the prototype's README.

### 6. Hand it over

Give the user the run command. They'll drive it themselves; the interesting moments are when they say "wait, that shouldn't be possible" or "huh, I assumed X would be different". Those are the bugs in the _idea_, which is the whole point. If they want new actions added, add them. Prototypes evolve.

### 7. Capture the answer and the prototype

Once the prototype has answered its question, capture the answer, then capture the prototype the way the [SKILL](SKILL.md) describes. The logic-specific mapping: the validated reducer / machine / function set lifts into the real module (the decision, absorbed); the TUI shell rides along to the throwaway branch that keeps the prototype as a primary source, where its one run command keeps it trivially re-runnable.

If the user is around, ask what the prototype taught them. If not, leave the verdict as a placeholder on the implementation issue so they (or you, on the next pass) can fill it in.

## Android / Kotlin

The logic prototype fits Android well because the bit worth keeping (the reducer, state machine, or use case) should already be **pure Kotlin with no Android imports**. Build it in a throwaway JVM module with the `application` plugin, keep the state model free of `ViewModel`, `Context`, `Flow`-plumbing, and `Log`, and wrap it in a `fun main()` console loop.

```kotlin
// Pure: liftable straight into the real module later
data class CheckoutState(val items: List<Item>, val status: Status)
fun reduce(state: CheckoutState, action: CheckoutAction): CheckoutState = ...

// Throwaway shell: fun main(), readLine() loop, println the whole state each tick
fun main() {
    var state = CheckoutState(emptyList(), Status.Empty)
    while (true) {
        clearScreen(); render(state)
        state = reduce(state, parse(readLine()) ?: continue)
    }
}
```

Run with `./gradlew :prototype:run`. When the model feels right, the reducer/state types move into the ViewModel's module unchanged; the `main()` shell goes to the throwaway branch, not main. A scratch JUnit test driving the reducer through a sequence of actions is a fine alternative shell if a console loop is overkill, but keep it throwaway, not a real test.

## Apple / Swift

Same shape: the reducer and state types are plain Swift with no `UIKit`/`SwiftUI` imports, in a library target. A sibling executable target in `Package.swift` wraps them in a `readLine()` loop that clears the screen and prints the whole state each tick. Run with `swift run <prototype-name>`.

## Anti-patterns

- **Don't add tests.** A prototype that needs tests is no longer a prototype.
- **Don't wire it to the real database.** Use in-memory state unless the question is specifically about persistence.
- **Don't generalise.** No "what if we wanted to support X later." The prototype answers one question.
- **Don't blur the logic and the TUI together.** If the reducer / state machine references `println`, prompts, or terminal escape codes, it's no longer liftable. Keep the TUI as a thin shell over a pure module.
- **Don't ship the TUI shell into production.** The shell is optimised for being driven by hand from a terminal. The logic module behind it is the bit worth keeping.
