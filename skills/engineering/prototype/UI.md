# UI Prototype

Generate **several radically different UI variations** on a single screen, switchable from a floating bottom bar. The user flips between variants in the running app, picks one (or steals bits from each), then throws the rest away.

If the question is about logic/state rather than what something looks like — wrong branch. Use [LOGIC.md](LOGIC.md).

## When this is the right shape

- "What should this screen look like?"
- "I want to see a few options for this dashboard before committing."
- "Try a different layout for the settings screen."
- Any time the user would otherwise spend a day picking between three vague mockups in their head.

## Two sub-shapes — strongly prefer sub-shape A

A UI prototype is much easier to judge when it's **butting up against the rest of the app** — real top bar, real navigation, real data, real density. A throwaway destination on its own is a vacuum: every variant looks fine in isolation. Default to sub-shape A whenever there's a plausible existing screen to host the variants. Only reach for sub-shape B if the prototype genuinely has no nearby home.

### Sub-shape A — adjustment to an existing screen (preferred)

The screen already exists. Variants are rendered **inside the same screen composable/view**, gated by a hoisted `variant` state. The existing state, ViewModel, and navigation all stay — only the rendering swaps. This is the default; pick it unless there's a specific reason not to.

If the prototype is for something that doesn't yet have a screen but *would naturally live inside one* (a new section of the dashboard, a new card on the settings screen, a new step in an existing flow) — that's still sub-shape A. Mount the variants inside the host screen.

### Sub-shape B — a new screen (last resort)

Only use this when the thing being prototyped genuinely has no existing screen to live inside — e.g. an entirely new top-level surface, or a flow that can't be embedded anywhere sensible.

Create a **throwaway destination** following whatever navigation convention the project already uses — don't invent a new top-level structure. Name it so it's obviously a prototype (e.g. include the word `Prototype` in the route object or filename). Same hoisted-`variant` pattern.

Before committing to sub-shape B, sanity-check: is there really no existing screen this could be embedded in? An empty destination hides design problems that a populated one would expose.

In both sub-shapes the floating bottom bar is identical.

## Process

### 1. State the question and pick N

Default to **3 variants**. More than 5 stops being radically different and starts being noise — cap there.

Write down the plan in one line, in the prototype's location or a top-of-file comment:

> "Three variants of the settings screen, switchable via a debug-only bottom bar, on the existing `SettingsScreen`."

This works whether the user is here to push back or not.

### 2. Generate radically different variants

Draft each variant. Hold each one to:

- The screen's purpose and the state it has access to.
- The project's design system (Material 3, a custom Compose theme, SwiftUI + a shared `DesignSystem` module, whatever).
- A clear composable/view name, e.g. `SettingsVariantA`, `SettingsVariantB`, `SettingsVariantC`.

Variants must be **structurally different** — different layout, different information hierarchy, different primary affordance, not just different colours. Three slightly-tweaked card grids isn't a UI prototype, it's wallpaper. If two drafts come out too similar, redo one with explicit "do not use a card grid" guidance.

### 3. Wire them together

Hoist a single `variant` state on the screen and branch over it, feeding every variant the same state and action handler:

```kotlin
@Composable
fun SettingsScreenWithVariants(state: SettingsState, onAction: (SettingsAction) -> Unit) {
    var variant by rememberSaveable { mutableStateOf("A") }
    Box(Modifier.fillMaxSize()) {
        when (variant) {
            "A" -> SettingsVariantA(state, onAction)
            "B" -> SettingsVariantB(state, onAction)
            else -> SettingsVariantC(state, onAction)
        }
        if (BuildConfig.DEBUG) {
            PrototypeSwitcher(
                variants = listOf("A", "B", "C"),
                current = variant,
                onSelect = { variant = it },
                modifier = Modifier.align(Alignment.BottomCenter),
            )
        }
    }
}
```

`rememberSaveable` keeps the chosen variant across rotation and process death, so a comparison survives the config changes you actually want to test the layouts against.

For sub-shape A (existing screen): keep all the existing state hoisting and ViewModel wiring above the switcher; only the rendered subtree changes per variant.

For sub-shape B (new screen): the throwaway destination mounts the same switcher.

**Quick static comparison** — when you don't need a running app and the difference is purely visual, skip the switcher: one `@Preview` per variant fed the same fake state, viewed side by side in the Studio preview pane. Faster, but it can't show you real data density.

### 4. Build the floating switcher

A small bar aligned to the bottom-centre of the screen with three pieces:

- **Left arrow** — cycles to the previous variant (wraps around).
- **Variant label** — shows the current variant key and, if the variant exposes a name, that name too. e.g. `B — Rail layout`.
- **Right arrow** — cycles forward (wraps around).

Behaviour:

- Tapping an arrow updates the hoisted `variant` state. Because it's `rememberSaveable`, the choice survives rotation and process death.
- Visually distinct from the screen (e.g. high-contrast pill, subtle shadow) so it's obviously not part of the design being evaluated.
- Hidden in production builds — gate on `BuildConfig.DEBUG` (Compose) or `#if DEBUG` (SwiftUI), so a stray prototype merge can't ship the bar to users.
- Mark it `@Composable` with no `contentDescription` obligations beyond the arrows themselves; it is scaffolding, not product UI.

Put the switcher in a single shared composable/view so both sub-shapes can reuse it. Locate it wherever shared debug UI lives in the project.

### 5. Hand it over

Tell the user how to reach the screen and which variant keys exist. They'll flip through whenever they get to it. The interesting feedback is usually **"I want the header from B with the rail from C"** — that's the actual design they want.

### 6. Capture the answer and clean up

Once a variant has won, write down which one and why (commit message, ADR, issue, or a `NOTES.md` next to the prototype if running AFK and the user hasn't responded yet). Then:

- **Sub-shape A** — delete the losing variants and the switcher; fold the winner into the existing screen.
- **Sub-shape B** — promote the winning variant to a real destination, delete the throwaway one and the switcher.

Delete the `@Preview`s that only existed to compare variants. Don't leave variant composables or the switcher lying around. They rot fast and confuse the next reader.

## SwiftUI (Apple)

Same shape, different primitives. Hoist the variant in `@State` (or `@SceneStorage` if you want it to survive relaunch), branch in `body`, and gate the bar on `#if DEBUG`:

```swift
struct SettingsScreenWithVariants: View {
    let state: SettingsState
    let onAction: (SettingsAction) -> Void
    @SceneStorage("prototypeVariant") private var variant = "A"

    var body: some View {
        ZStack(alignment: .bottom) {
            switch variant {
            case "A": SettingsVariantA(state: state, onAction: onAction)
            case "B": SettingsVariantB(state: state, onAction: onAction)
            default:  SettingsVariantC(state: state, onAction: onAction)
            }
            #if DEBUG
            PrototypeSwitcher(variants: ["A", "B", "C"], current: $variant)
            #endif
        }
    }
}
```

The static-comparison equivalent is one `#Preview` per variant fed the same fake `SettingsState`.

## Anti-patterns

- **Variants that differ only in colour or copy.** That's a tweak, not a prototype. Real variants disagree about structure — layout and information hierarchy, not `MaterialTheme`/`Color` tokens.
- **Sharing too much code between variants.** A shared `SettingsHeader()` is fine; a shared `SettingsLayout()` defeats the point. Each variant should be free to throw out the layout.
- **Wiring variants to real mutations.** Read-only prototypes are fine. Point variants at fake state (a `SettingsState` literal), never real mutations. If a variant needs to mutate, point it at a stub — the question is "what should this look like", not "does the backend work".
- **Promoting the prototype directly to production.** The variant code was written under prototype constraints (no tests, minimal error handling). Rewrite it properly when you fold it in.
