# Subagent delegation — Swift / Apple-platform projects

When to spawn a subagent vs. do the work in the main thread.

## Delegate when

- **Read-heavy exploration**: "find every callsite of `OldAuthInterceptor`", "map how navigation is wired across feature packages". Subagent returns a compact map; main thread keeps a clean context.
- **Parallelizable**: two independent investigations (e.g. "audit `CoreNetworking` for security gaps" + "review `FeatureProfile` for SwiftUI re-render churn"). Spawn both in one message — they run concurrently.
- **Cross-module audits**: SwiftLint suppressions across the repo, unused assets, dead code, force-unwraps. The result is a list, not a long discussion.
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
| Stuck / want a Codex second pass | `codex:codex-rescue` |
| Open-ended research across web + repo + docs | `general-purpose` |
| Multi-step task that doesn't fit above | `general-purpose` |

## Prompt rules

- Brief like a colleague who just walked in: goal, what's been tried, what to decide. No conversation backref.
- Hand over the **question** for investigations, the **command** for lookups.
- Tell the agent if you want code written or only research — it cannot infer intent.
- Cap response length when you can: "report in under 200 words", "punch list, no prose".
- Include file paths and line numbers when delegating an implementation. Never push synthesis onto the agent.
- For Apple-platform work, include the package/target (`FeatureProfile`), the relevant scheme/configuration, and the deployment target / OS version if behavior is API-availability dependent.

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
