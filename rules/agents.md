# Subagent delegation — Android projects

When to spawn a subagent vs. do the work in the main thread.

## Delegate when

- **Read-heavy exploration**: "find every callsite of `OldAuthInterceptor`", "map how navigation is wired across feature modules". Subagent returns a compact map; main thread keeps a clean context.
- **Parallelizable**: two independent investigations (e.g. "audit `:core:network` for security gaps" + "review `:feature:profile` for Compose stability"). Spawn both in one message — they run concurrently.
- **Cross-module audits**: ktlint/detekt suppressions across the repo, unused resources, dead code. The result is a list, not a long discussion.
- **Codex rescue / second opinion**: deep root-cause investigation on a bug after one failed fix attempt, or an independent code review against a Plan.
- **Independent review of own work**: after finishing a non-trivial PR-ready change, dispatch a reviewer subagent so the critique isn't anchored to the implementer's reasoning.

## Do NOT delegate

- A targeted lookup with a known path or symbol — use `Read` or `grep` directly.
- Synthesis or design decisions. Never `"based on your findings, fix the bug"`. The main thread owns judgement; subagents fetch facts.
- Anything < 3 file reads. Spawn cost dwarfs the saving.
- Trivial edits, mechanical renames, doc tweaks — main thread is faster.
- Anything the user is watching you do step-by-step. Delegation hides progress.

## Picking the agent type

| Task | Agent |
|---|---|
| Locate code, "where is X defined" | `Explore` (read-only, fast) |
| Design a feature architecture | `feature-dev:code-architect` |
| Trace an existing feature end-to-end | `feature-dev:code-explorer` |
| Pre-PR code review | `feature-dev:code-reviewer` or `pr-review-toolkit:code-reviewer` |
| Independent reviewer for ureview workflow | `up:reviewer` |
| Stuck / want a Codex second pass | `codex:codex-rescue` |
| Open-ended research across web + repo + docs | `up:researcher` |
| Implement one approved phase of a plan | `up:implementer` (Opus) or `up:implementer-sonnet` (trivial only) |
| Multi-step task that doesn't fit above | `general-purpose` |

## Prompt rules

- Brief like a colleague who just walked in: goal, what's been tried, what to decide. No conversation backref.
- Hand over the **question** for investigations, the **command** for lookups.
- Tell the agent if you want code written or only research — it cannot infer intent.
- Cap response length when you can: "report in under 200 words", "punch list, no prose".
- Include file paths and line numbers when delegating an implementation. Never push synthesis onto the agent.
- For Android-specific work, include the module path (`:feature:profile`), the relevant `build.gradle.kts` flavor/variant context, and the min/target SDK if behavior is API-level dependent.

## Parallel dispatch

- Independent calls → single message with multiple `Agent` blocks. The runtime parallelizes.
- Dependent calls → sequential. Don't fake parallelism by passing placeholders.

## After the agent returns

- Trust but verify. The summary is the agent's intent, not necessarily the diff. Read the changes before claiming completion.
- Relay a concise summary to the user — the agent's full output is not user-visible.
- If the agent's findings change the plan, update the plan (Plan tool or task file), not just memory.

## Budget

- Max 3 concurrent agents per turn unless the user asked for "in parallel" explicitly.
- Never chain agents recursively without checking the result. Agent A → Agent B → Agent C invites context drift.

See also: [performance.md](performance.md), [hooks.md](hooks.md).
