# Hooks — Swift / Apple-platform project automation

Two flavors of "hooks" in this repo:
1. **Git hooks** that gate commits/pushes.
2. **Claude Code hooks** that gate tool use during AI-assisted work.

Both share the same purpose: shift validation left and refuse invalid state automatically.

---

## 1. Git hooks

Managed via [pre-commit](https://pre-commit.com/) or a `scripts/git-hooks/` directory installed by a `make install-git-hooks` step. Hooks must be fast — every developer pays the cost on every commit.

### pre-commit (target < 5s)

- **SwiftFormat** `--lint` on staged Swift files only.
- **SwiftLint** on staged files (`--use-script-input-files`).
- **secret-scan**: regex sweep for `Authorization`, `Bearer`, `-----BEGIN`, `api[_-]?key`, `AIza[0-9A-Za-z\-_]{35}`, `gh[pousr]_[A-Za-z0-9]{36,}`. Reject on match.
- **forbidden-files**: refuse `xcuserdata/`, `*.xcuserstate`, `DerivedData/`, `.xcconfig` with secrets, `*.p12`, `*.mobileprovision`, `*.cer`.
- **Info.plist / entitlements guard**: if an `Info.plist` `NS*UsageDescription` or an `.entitlements` file changed, print the diff and exit non-zero unless an env flag confirms the permission/capability change is intentional.

### commit-msg (target < 1s)

- Validate Conventional Commits format (see [git-workflow.md](git-workflow.md)).
- Reject subject > 50 chars, body lines > 72 chars (excluding `BREAKING CHANGE:` and URLs).
- Enforce allowed types and that the scope matches `^[a-z0-9-]+$`.

### pre-push (target < 60s)

- `swift build` (packages) or `xcodebuild build` on the touched scheme.
- `swift test` on the cheap `Core*` packages (always — they catch the most regressions).
- Block push to `main` from a local branch (force PR flow).

### post-checkout / post-merge

- Optional convenience: resolve packages (`xcodebuild -resolvePackageDependencies`) if `Package.resolved` changed. Off by default.

### Bypassing

- `--no-verify` only during an active incident, paired with a follow-up issue. Hooks log bypass attempts to `.git/hooks.log`.

---

## 2. Claude Code hooks

Configured in `.claude/settings.json` (project) or `~/.claude/settings.json` (user). Use the `update-config` skill to add/modify.

### Event types

| Event | When it fires | Typical use |
|---|---|---|
| `PreToolUse` | Before a tool runs | Block dangerous Bash, validate file paths, gate destructive ops |
| `PostToolUse` | After a tool returns | Auto-format edited files, run lint on changed scope |
| `UserPromptSubmit` | When user sends a message | Inject context (active branch, current task), enforce mode banners |
| `Stop` / `SubagentStop` | When Claude or a subagent finishes | Run the confidence gate, prompt for `/commit` |
| `SessionStart` | New session starts | Load `.remember/now.md`, show active TODOs |
| `SessionEnd` | Session ends | Persist session state to `.remember/today-*.md` |
| `PreCompact` | Before context compaction | Snapshot key decisions to disk before they're summarized away |
| `Notification` | Claude pings the user | Custom routing (Slack, native notification) |

### Project hooks (in `.claude/settings.json`)

Recommended for Apple-platform repos:

- **PreToolUse:Bash** — block `rm -rf`, `git push --force` to protected branches, `xcodebuild clean`/`rm -rf DerivedData` without confirmation when there are uncommitted changes.
- **PostToolUse:Edit/Write on `**/*.swift`** — run `swiftformat` then `swiftlint --fix --quiet` on the modified file. Surface remaining warnings inline.
- **PostToolUse:Edit/Write on `**/Info.plist` or `**/*.entitlements`** — diff usage strings / capabilities; require explicit acknowledgment in the next assistant turn.
- **PostToolUse:Edit/Write on `Package.swift` / `Package.resolved`** — resolve packages and surface added/changed dependencies for review.
- **Stop** — invoke the confidence-gate skill if a commit/PR is on the table. Block the `Stop` with a reminder if `confidence.md` is missing or < 10/10.
- **UserPromptSubmit** — inject the current `git status --short` and the top item from `.remember/now.md` so each turn starts with context.
- **SessionStart** — load `.remember/now.md` and any active task file.

### Hook contract

- Hooks run as shell scripts. Exit 0 = allow. Non-zero = block (PreToolUse) or report (PostToolUse).
- stdout is echoed into the conversation as a system reminder.
- Keep hook output **terse**: one line for "allowed", a focused diagnostic for "blocked". Long output bloats context.
- Hooks must be idempotent and side-effect-free unless that's their declared job (formatting, logging).
- Hooks must finish < 2s for `PreToolUse`, < 10s for `PostToolUse`. Longer = degraded UX. (A full `xcodebuild` is too slow for a hook — keep builds in git pre-push, not Claude hooks.)

### Writing a hook

Use the `hookify` plugin (`/hookify` or `/hookify <natural-language-rule>`). For a bespoke hook:

1. Drop the script in `.claude/hooks/<name>.sh` (or `${CLAUDE_PLUGIN_ROOT}/hooks/` if shipping in a plugin).
2. Register in `.claude/settings.json`:
   ```json
   {
     "hooks": {
       "PostToolUse": [
         {
           "matcher": "Edit|Write",
           "filter": { "filePattern": "**/*.swift" },
           "command": ".claude/hooks/swiftformat-lint.sh \"$CLAUDE_FILE_PATH\""
         }
       ]
     }
   }
   ```
3. Test with a real edit. Roll back if it adds > 2s latency.

### Forbidden hook behaviors

- Auto-committing on `Stop`. Commits are user-authorized.
- Calling external APIs that require secrets without explicit user consent on every session.
- Modifying files outside the tool's stated scope (e.g. a `PostToolUse:Edit` hook editing other files).
- Silent failures. A hook that errors must say so in stdout.

### Listing & toggling

- `/hookify:list` shows configured rules.
- `/hookify:configure` toggles them interactively.
- Disable a hook by commenting it out in `.claude/settings.json`; don't delete unless you're sure.

See also: [agents.md](agents.md), [git-workflow.md](git-workflow.md), [security.md](security.md).
