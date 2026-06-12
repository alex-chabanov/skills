#!/usr/bin/env bash
set -euo pipefail

# SessionStart hook: detect the active project's platform and inject ONLY the
# matching ruleset. Replaces the old unconditional ~/.claude/rules symlink that
# loaded Android rules into every project (and would contradict Swift rules if
# both were made global). stdout becomes session context.

RULES_ROOT="/Users/alex/Documents/projects/skills/rules"
cwd="${CLAUDE_PROJECT_DIR:-$PWD}"

emit() {
  local platform="$1"
  echo "# ${platform} project rules (auto-loaded by detect-rules.sh)"
  echo
  find "$RULES_ROOT/$2" -maxdepth 1 -name '*.md' | sort | while IFS= read -r f; do
    echo "## rules/$2/$(basename "$f")"
    echo
    cat "$f"
    echo
  done
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

if is_android; then
  emit "Android" android
elif is_swift; then
  emit "Swift" swift
fi
# neither matched -> emit nothing; project gets no platform-specific rules
