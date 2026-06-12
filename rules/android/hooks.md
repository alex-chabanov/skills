# Hooks — Android project automation

Two flavors of "hooks" in this repo:
1. **Git hooks** that gate commits/pushes.
2. **Claude Code hooks** that gate tool use during AI-assisted work.

Both share the same purpose: shift validation left and refuse invalid state automatically.

---

## 1. Git hooks

Managed via [pre-commit](https://pre-commit.com/) or a `scripts/git-hooks/` directory installed by `./gradlew installGitHooks`. Hooks must be fast — every developer pays the cost on every commit.

### pre-commit (target < 5s)

- **ktlint** on staged Kotlin files only (`--staged-only`).
- **detekt** on staged files using the autocorrect profile.
- **secret-scan**: regex sweep for `Authorization`, `Bearer`, `-----BEGIN`, `api[_-]?key`, `AIza[0-9A-Za-z\-_]{35}`, `gh[pousr]_[A-Za-z0-9]{36,}`. Reject on match.
- **forbidden-files**: refuse `.idea/`, `.DS_Store`, `local.properties`, `*.keystore`, `*.jks`, `google-services.json` (prod variant), `.gradle/` cache.
- **manifest-diff guard**: if `AndroidManifest.xml` changed, prompt for confirmation that the permission/exported diff is intentional (run `git diff --cached AndroidManifest.xml` and exit non-zero unless an env flag is set).

### commit-msg (target < 1s)

- Validate Conventional Commits format (see [git-workflow.md](git-workflow.md)).
- Reject subject > 50 chars, body lines > 72 chars (excluding `BREAKING CHANGE:` and URLs).
- Enforce allowed types and that the scope matches `^[a-z0-9-]+$`.

### pre-push (target < 60s)

- `./gradlew :app:assembleDebug` on the modules touched by the diverging commits.
- `./gradlew :core:network:test :core:domain:test` (always — they're cheap and they catch the most regressions).
- Block push to `main` from a local branch (force PR flow).

### post-checkout / post-merge

- Optional convenience: `./gradlew --stop && ./gradlew dependencies` warm-up if `libs.versions.toml` changed. Off by default.

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

Recommended for Android repos:

- **PreToolUse:Bash** — block `rm -rf`, `git push --force` to protected branches, `./gradlew clean` without confirmation in worktrees with uncommitted changes.
- **PostToolUse:Edit/Write on `**/*.kt`** — run `ktlint --format` and `detekt --auto-correct` on the modified file. Surface remaining warnings inline.
- **PostToolUse:Edit/Write on `AndroidManifest.xml`** — diff permissions and `exported` flags; require explicit acknowledgment in the next assistant turn.
- **PostToolUse:Edit/Write on `libs.versions.toml`** — run `./gradlew dependencyUpdates` and surface stale/known-vulnerable bumps.
- **Stop** — invoke `confidence-gate-android` skill if a commit/PR is on the table. Block the `Stop` with a reminder if `confidence.md` is missing or < 10/10.
- **UserPromptSubmit** — inject the current `git status --short` and the top item from `.remember/now.md` so each turn starts with context.
- **SessionStart** — load `.remember/now.md` and any active task file from `up:make`.

### Hook contract

- Hooks run as shell scripts. Exit 0 = allow. Non-zero = block (PreToolUse) or report (PostToolUse).
- stdout is echoed into the conversation as a system reminder.
- Keep hook output **terse**: one line is enough for "allowed", a focused diagnostic for "blocked". Long output bloats context.
- Hooks must be idempotent and side-effect-free unless that's their declared job (formatting, logging).
- Hooks must finish < 2s for `PreToolUse`, < 10s for `PostToolUse`. Longer = degraded UX.

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
           "filter": { "filePattern": "**/*.kt" },
           "command": ".claude/hooks/ktlint-format.sh \"$CLAUDE_FILE_PATH\""
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
