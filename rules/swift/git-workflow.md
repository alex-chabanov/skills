# Git workflow — Swift / Apple-platform projects

## Branching

- Trunk-based. Long-lived branches: `main` (always releasable) and release branches (`release/1.42.x`).
- Feature branches: short-lived (< 3 days). Name: `feat/<ticket>-short-slug`, `fix/<ticket>-short-slug`, `chore/<slug>`.
- Rebase onto `main` before opening a PR. No merge commits in feature branches.

## Conventional Commits

Format: `<type>(<scope>)<!>: <subject>`

```
feat(profile): add avatar upload
fix(auth): refresh token on 401 instead of logout
refactor(core-networking): split URLSession factory from API client
chore(deps): bump swift-collections to 1.1.0
docs(readme): document xcconfig keys
test(home): cover error state in HomeViewModel
perf(list): cut body re-evaluation in ChatList rows
build(xcode): enable library evolution for Core packages
ci(github): cache DerivedData and SPM between jobs
revert: revert "feat(profile): add avatar upload"
```

### Types

`feat`, `fix`, `refactor`, `perf`, `test`, `docs`, `chore`, `build`, `ci`, `style`, `revert`.

- `style` is formatting only; no logic change.
- `refactor` changes structure without changing behavior. A `refactor` PR must not change any test outcome.
- `feat` introduces user-visible behavior. New code without user-visible effect is `refactor` or `chore`.
- `!` after type/scope (or `BREAKING CHANGE:` footer) for breaking API/contract changes.

### Scope

- Package/target name (`auth`, `core-networking`, `feature-profile`) or top-level area (`xcode`, `ci`, `deps`).
- One scope per commit. If two scopes are equally affected, split the commit.

### Subject

- Imperative mood. "add", not "added"/"adds".
- ≤ 50 characters. Lowercase, no trailing period.

### Body

- Wrap at 72 chars. Explain **why** and **what changed in user-visible terms**, not the diff.
- Required for `feat`, `fix`, `perf`, `refactor` > 50 LOC, and any `BREAKING CHANGE`.
- Reference ticket: `Refs: APP-1234` or `Closes: APP-1234`.

### Footer

- `BREAKING CHANGE: <description>` — required for breaking changes.
- `Co-Authored-By: Name <email>` — required for pair work and AI-assisted commits.
- `Refs:` / `Closes:` for issue tracking.

## Atomic commits

- One logical change per commit. A commit must be revertable without breaking unrelated features.
- A commit must build and pass tests on its own (`swift test` / `xcodebuild test`). No "WIP" commits on `main`.
- Splitting a feature into a stack of commits is encouraged — each layer (data → domain → ui) can be its own commit.

## PR rules

- Title = first commit's subject. Body = motivation + screenshots/screen recordings for UI changes.
- Max 400 lines changed (excluding generated, `Package.resolved`, snapshots, `.pbxproj` churn). Larger PRs need an explicit "why splitting is harder than reviewing" note.
- Self-review the diff before requesting reviewers — `.pbxproj` and asset-catalog diffs especially.
- All checks green before merge: SwiftLint, SwiftFormat check, unit, snapshot, coverage.
- Squash-merge only if the branch has noisy fixup commits. Otherwise rebase-merge to preserve atomic commits.

## Hooks

- `pre-commit`: SwiftFormat + SwiftLint on staged Swift files. Fast — no full Xcode build.
- `commit-msg`: validate Conventional Commits format. Reject malformed type or subject.
- `pre-push`: `swift build` (or `xcodebuild build` on the touched scheme) smoke build.
- Never bypass with `--no-verify` outside an active incident. If you do, the next commit must restore green.

## Forbidden

- Force-push to `main` or any shared release branch.
- Committing `xcuserdata/`, `*.xcuserstate`, `DerivedData/`, `.xcconfig` with secrets, `*.p12`, `*.mobileprovision`, `*.cer`, build artifacts.
- `git add .` without reviewing the staged set first — pulls in `xcuserdata` and editor cruft.
- Hand-editing `.pbxproj` to resolve a merge conflict without verifying the project still opens and builds.

See also: [security.md](security.md), [testing.md](testing.md).
