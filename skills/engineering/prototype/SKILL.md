---
name: prototype
description: Build a throwaway prototype to answer a design question. Use when the user wants to sanity-check whether a state model or logic feels right, or explore what a UI should look like.
---

# Prototype

A prototype is **throwaway code that answers a question**. The question decides the shape.

## Pick a branch

Identify which question is being answered — from the user's prompt, the surrounding code, or by asking if the user is around:

- **"Does this logic / state model feel right?"** → [LOGIC.md](LOGIC.md). Build a tiny interactive terminal app that pushes the state machine through cases that are hard to reason about on paper.
- **"What should this look like?"** → [UI.md](UI.md). Generate several radically different UI variations on a single screen, switchable via a hoisted `variant` state and a debug-only floating bottom bar.

The two branches produce very different artifacts — getting this wrong wastes the whole prototype. If the question is genuinely ambiguous and the user isn't reachable, default to whichever branch better matches the surrounding code (a domain or data module → logic; a screen or composable/view → UI) and state the assumption at the top of the prototype.

**Android / Kotlin:** a state machine, reducer, use case, or `Result`-returning data flow → logic ([LOGIC.md](LOGIC.md)), driven by a `fun main()` console app in a throwaway JVM module. A Compose screen → UI ([UI.md](UI.md)), variants behind a switcher in a debug build or as side-by-side `@Preview`s.

**Apple / Swift:** a reducer, use case, or `Result`-returning flow → logic, driven by a `swift run` executable target. A SwiftUI view → UI, variants behind a `#if DEBUG` switcher or side-by-side `#Preview`s.

## Rules that apply to both

1. **Throwaway from day one, and clearly marked as such.** Locate the prototype code close to where it will actually be used (next to the module or screen it's prototyping for) so context is obvious — but name it so a casual reader can see it's a prototype, not production. For a throwaway UI destination, obey whatever navigation convention the project already uses; don't invent a new top-level structure.
2. **One command to run.** Whatever the project's existing task runner supports — `./gradlew :prototype:run`, `swift run <name>`, `xcodebuild -scheme <Preview>`, `python <path>`, etc. The user must be able to start it without thinking.
3. **No persistence by default.** State lives in memory. Persistence is the thing the prototype is _checking_, not something it should depend on. If the question explicitly involves a database, hit a scratch DB or a local file with a clear "PROTOTYPE — wipe me" name.
4. **Skip the polish.** No tests, no error handling beyond what makes the prototype _runnable_, no abstractions. The point is to learn something fast and then delete it.
5. **Surface the state.** After every action (logic) or on every variant switch (UI), print or render the full relevant state so the user can see what changed.
6. **Delete or absorb when done.** When the prototype has answered its question, either delete it or fold the validated decision into the real code — don't leave it rotting in the repo.

## When done

The _answer_ is the only thing worth keeping from a prototype. Capture it somewhere durable (commit message, ADR, issue, or a `NOTES.md` next to the prototype) along with the question it was answering. If the user is around, that capture is a quick conversation; if not, leave the placeholder so they (or you, on the next pass) can fill in the verdict before deleting the prototype.
