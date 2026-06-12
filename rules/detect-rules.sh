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

is_android() {
  any_exists "$cwd"/build.gradle "$cwd"/build.gradle.kts "$cwd"/settings.gradle \
     "$cwd"/settings.gradle.kts "$cwd"/gradlew && return 0
  find "$cwd" -maxdepth 2 -name '*.gradle*' -print -quit 2>/dev/null | grep -q .
}

is_swift() {
  any_exists "$cwd"/Package.swift "$cwd"/Podfile && return 0
  find "$cwd" -maxdepth 1 \( -name '*.xcodeproj' -o -name '*.xcworkspace' \) \
     -print -quit 2>/dev/null | grep -q .
}

if is_android; then
  emit "Android" android
elif is_swift; then
  emit "Swift" swift
fi
# neither matched -> emit nothing; project gets no platform-specific rules
