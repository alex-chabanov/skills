#!/usr/bin/env bash
set -euo pipefail

# SessionStart hook: detect the active project's platform and inject ONLY the
# matching ruleset. Replaces the old unconditional ~/.claude/rules symlink that
# loaded Android rules into every project (and would contradict Swift rules if
# both were made global). stdout becomes session context.

# Resolve this script's own directory, following symlinks. `dirname "$0"` alone would
# point at the symlink's directory, not the repo, and `readlink -f` is not portable to
# the BSD readlink shipped on older macOS.
# No cycle guard is needed: the OS refuses to open a cyclic symlink (ELOOP), so bash
# never reaches this loop with one. A hop cap would only misfire on long valid chains.
src="${BASH_SOURCE[0]}"
while [ -L "$src" ]; do
  dir="$(cd -P "$(dirname "$src")" && pwd)"
  src="$(readlink "$src")"
  case $src in /*) ;; *) src="$dir/$src" ;; esac
done
RULES_ROOT="$(cd -P "$(dirname "$src")" && pwd)"
cwd="${CLAUDE_PROJECT_DIR:-$PWD}"

# A wrong RULES_ROOT must be loud, not silent: this hook's entire job is injecting the
# platform rules, and silently injecting none looks identical to "no platform detected".
if [ ! -d "$RULES_ROOT/android" ] && [ ! -d "$RULES_ROOT/swift" ] && [ ! -d "$RULES_ROOT/common" ]; then
  echo "detect-rules.sh: no rulesets under $RULES_ROOT — platform rules will NOT load" >&2
  exit 0
fi

# When to read each rule file, keyed by basename. Files not listed still appear in
# the index with a generic hint, so adding a rule file never requires editing this.
read_when() {
  case "$1" in
    coding-style.md) echo "before writing, editing, or reviewing any source code" ;;
    patterns.md)     echo "before adding API/error/state/navigation code" ;;
    testing.md)      echo "before writing or changing tests" ;;
    security.md)     echo "before touching secrets, auth, storage, networking, or merging" ;;
    performance.md)  echo "before perf work or choosing a model for subagents" ;;
    git-workflow.md) echo "before committing, branching, or opening a PR" ;;
    agents.md)       echo "before deciding whether to spawn a subagent" ;;
    hooks.md)        echo "before adding or changing git hooks or Claude Code hooks" ;;
    *)               echo "when its topic is relevant" ;;
  esac
}

# Emit an INDEX, not the rule bodies. SessionStart stdout above the hook-output cap
# is replaced by a ~2KB preview plus a file path, so cat-ing ~45KB of rules here
# silently dropped ~95% of them. Paths are absolute so the model can Read them.
emit() {
  local platform="$1" dir="$RULES_ROOT/$2"
  # A missing ruleset must not abort the session hook — emit nothing and move on.
  [ -d "$dir" ] || return 0
  echo "# ${platform} project rules (auto-loaded by detect-rules.sh)"
  echo
  echo "These ${platform} rules apply to this project. They are NOT inlined: Read the"
  echo "matching file with the Read tool at the moment listed, before acting. They"
  echo "override existing code patterns."
  echo
  find "$dir" -maxdepth 1 -name '*.md' | sort | while IFS= read -r f; do
    local name title
    name="$(basename "$f")"
    title="$(sed -n 's/^# //p' "$f" | head -1)"
    echo "- \`$f\` — ${title:-$name}. Read $(read_when "$name")."
  done
  echo
}

any_exists() { for f in "$@"; do [ -e "$f" ] && return 0; done; return 1; }

# Search for a marker up to maxdepth, pruning heavy/vendored dirs so a marker
# inside a dependency or build output never triggers a false positive. Markers
# can sit below the root: Android multi-module (feature/x/build.gradle.kts) and
# Swift SPM monorepos (Packages/Core/Package.swift) both nest one or two levels.
MARKER_MAXDEPTH=3

find_marker() {
  find "$cwd" -maxdepth "$MARKER_MAXDEPTH" \
    \( -name .git -o -name node_modules -o -name build -o -name .build \
       -o -name DerivedData -o -name .gradle -o -name Pods \) -prune -o \
    \( "$@" \) -print -quit 2>/dev/null | grep -q .
}

is_android() {
  any_exists "$cwd"/build.gradle "$cwd"/build.gradle.kts "$cwd"/settings.gradle \
     "$cwd"/settings.gradle.kts "$cwd"/gradlew && return 0
  find_marker -name '*.gradle' -o -name '*.gradle.kts'
}

is_swift() {
  any_exists "$cwd"/Package.swift "$cwd"/Podfile && return 0
  find_marker -name Package.swift -o -name Podfile \
     -o -name '*.xcodeproj' -o -name '*.xcworkspace'
}

# Common rules apply to every project and are INLINED, unlike the platform index.
# They are always-on behavior (not a lookup a task triggers), and an index entry or a
# skill is read only when the model decides to, and for advice this generic it never
# does. Keep each file short: inlined bytes count toward the hook-output cap that the
# test suite guards.
if [ -d "$RULES_ROOT/common" ]; then
  find "$RULES_ROOT/common" -maxdepth 1 -name '*.md' | sort | while IFS= read -r f; do
    cat "$f"
    echo
  done
fi

# Checked independently, not as an if/elif chain: a KMP repo with an iOS app matches
# both, and confidence-gate's platform mode expects both rulesets to be present so it
# can run dimensions 7-12 for each. Neither matched -> emit nothing.
if is_android; then
  emit "Android" android
fi
if is_swift; then
  emit "Swift" swift
fi
