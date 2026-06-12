# Git workflow — Android projects

## Branching

- Trunk-based. Long-lived branches: `main` (always releasable) and release branches (`release/1.42.x`).
- Feature branches: short-lived (< 3 days). Name: `feat/<ticket>-short-slug`, `fix/<ticket>-short-slug`, `chore/<slug>`.
- Rebase onto `main` before opening a PR. No merge commits in feature branches.

## Conventional Commits

Format: `<type>(<scope>)<!>: <subject>`

```
feat(profile): add avatar upload
fix(auth): refresh token on 401 instead of logout
refactor(core-network): split RetrofitFactory into client + service
chore(deps): bump kotlinx-coroutines to 1.9.0
docs(readme): document local.properties keys
test(home): cover error state in HomeViewModel
perf(list): reduce recomposition in ChatList items
build(gradle): enable configuration cache
ci(github): cache Gradle home between jobs
revert: revert "feat(profile): add avatar upload"
```

### Types

`feat`, `fix`, `refactor`, `perf`, `test`, `docs`, `chore`, `build`, `ci`, `style`, `revert`.

- `style` is formatting only; no logic change.
- `refactor` changes structure without changing behavior. A `refactor` PR must not change any test outcome.
- `feat` introduces user-visible behavior. New code without user-visible effect is `refactor` or `chore`.
- `!` after type/scope (or `BREAKING CHANGE:` footer) for breaking API/contract changes.

### Scope

- Module name (`auth`, `core-network`, `feature-profile`) or top-level area (`gradle`, `ci`, `deps`).
- One scope per commit. If two scopes are equally affected, split the commit.

### Subject

- Imperative mood. "add", not "added"/"adds".
- ≤ 50 characters.
- Lowercase, no trailing period.

### Body

- Wrap at 72 chars. Explain **why** and **what changed in user-visible terms**, not the diff.
- Required for `feat`, `fix`, `perf`, `refactor` > 50 LOC, and any `BREAKING CHANGE`.
- Reference ticket: `Refs: APP-1234` or `Closes: APP-1234`.

### Footer

- `BREAKING CHANGE: <description>` — required for breaking changes.
- `Co-Authored-By: Name <email>` — required for pair work and for AI-assisted commits.
- `Refs:` / `Closes:` for issue tracking.

## Atomic commits

- One logical change per commit. A commit must be revertable without breaking unrelated features.
- A commit must compile and pass `./gradlew check` on its own. No "WIP" commits on `main`.
- Splitting a feature into a stack of commits is encouraged — each layer (data → domain → ui) can be its own commit.

## PR rules

- Title = first commit's subject. Body = motivation + screenshots/screen recordings for UI changes.
- Max 400 lines changed (excluding generated, lockfiles, snapshots). Larger PRs need an explicit "why splitting is harder than reviewing" note.
- Self-review the diff before requesting reviewers.
- All checks green before merge: ktlint, detekt, unit, Robolectric, coverage, OWASP dep-check.
- Squash-merge only if the branch has noisy fixup commits. Otherwise rebase-merge to preserve atomic commits.

## Hooks

- `pre-commit`: ktlint + detekt on staged files. Fast — no full Gradle build.
- `commit-msg`: validate Conventional Commits format. Reject if the type or subject is malformed.
- `pre-push`: `./gradlew :app:assembleDebug` smoke build on the changed module set.
- Never bypass with `--no-verify` outside an active incident. If you do, the next commit must restore green.

## Forbidden

- Force-push to `main` or any shared release branch.
- Committing `.idea/`, `.DS_Store`, `local.properties`, `*.keystore`, `google-services.json` with prod IDs, `.gradle/` caches.
- `git add .` without reviewing the staged set first — pulls in editor swap files and secrets.

See also: [security.md](security.md), [testing.md](testing.md).
