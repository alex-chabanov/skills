#!/usr/bin/env bash
set -uo pipefail

# Regression tests for detect-rules.sh. Run: bash rules/detect-rules.test.sh
#
# The bug this guards: detect-rules.sh once used `if is_android; elif is_swift`, so a KMP
# repo with an iOS app silently got Android rules only — while confidence-gate's platform
# mode promises both rulesets. See the `kmp` case below.

SCRIPT="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)/detect-rules.sh"
FIX="$(mktemp -d)"
trap 'rm -rf "$FIX"' EXIT

pass=0 fail=0
check() { # check <name> <expected> <actual>
  if [ "$2" = "$3" ]; then pass=$((pass + 1)); printf '  ok   %-34s %s\n' "$1" "$2"
  else fail=$((fail + 1)); printf '  FAIL %-34s expected=%s actual=%s\n' "$1" "$2" "$3"; fi
}

# Emit the detected platforms, joined with '+', for a fixture directory.
platforms() {
  CLAUDE_PROJECT_DIR="$1" bash "$SCRIPT" 2>/dev/null \
    | sed -n 's/^# \([A-Za-z]*\) project rules.*/\1/p' | paste -sd+ - | tr -d '[:space:]'
}

mk() { mkdir -p "$FIX/$1"; shift; for f in "$@"; do mkdir -p "$FIX/$(dirname "$f")"; touch "$FIX/$f"; done; }

mk android_root        android_root/build.gradle.kts
mk android_nested      android_nested/feature/x/build.gradle.kts
mk swift_package       swift_package/Package.swift
mk swift_xcodeproj     swift_xcodeproj/App.xcodeproj
mk swift_spm_monorepo  swift_spm_monorepo/Packages/Core/Package.swift
mk neutral             neutral/src/main.py
mk vendored            vendored/node_modules/dep/Package.swift
mk kmp                 kmp/build.gradle.kts kmp/iosApp/App.xcodeproj

echo "detect-rules.sh"
check "android at root"        "Android"       "$(platforms "$FIX/android_root")"
check "android nested module"  "Android"       "$(platforms "$FIX/android_nested")"
check "swift Package.swift"    "Swift"         "$(platforms "$FIX/swift_package")"
check "swift xcodeproj"        "Swift"         "$(platforms "$FIX/swift_xcodeproj")"
check "swift SPM monorepo"     "Swift"         "$(platforms "$FIX/swift_spm_monorepo")"
check "neutral repo is silent" ""              "$(platforms "$FIX/neutral")"
check "vendored dirs pruned"   ""              "$(platforms "$FIX/vendored")"
check "KMP emits BOTH"         "Android+Swift" "$(platforms "$FIX/kmp")"

# A SessionStart hook must never fail the session, whatever it is pointed at.
for case in android_root neutral kmp; do
  CLAUDE_PROJECT_DIR="$FIX/$case" bash "$SCRIPT" >/dev/null 2>&1
  check "exit 0 ($case)" "0" "$?"
done

# RULES_ROOT must survive symlinked invocation — link-skills.sh symlinks into ~/.claude.
ln -sf "$SCRIPT" "$FIX/link.sh"
ln -sf "$FIX/link.sh" "$FIX/link2.sh"
check "resolves through symlink"       "Android" "$(CLAUDE_PROJECT_DIR="$FIX/android_root" bash "$FIX/link.sh"  2>/dev/null | sed -n 's/^# \([A-Za-z]*\) project rules.*/\1/p')"
check "resolves through symlink chain" "Android" "$(CLAUDE_PROJECT_DIR="$FIX/android_root" bash "$FIX/link2.sh" 2>/dev/null | sed -n 's/^# \([A-Za-z]*\) project rules.*/\1/p')"

# A copy detached from rules/ must warn loudly rather than silently inject nothing.
cp "$SCRIPT" "$FIX/orphan.sh"
orphan_err="$(CLAUDE_PROJECT_DIR="$FIX/android_root" bash "$FIX/orphan.sh" 2>&1 >/dev/null)"
check "orphaned copy warns on stderr" "warned" "$([ -n "$orphan_err" ] && echo warned || echo silent)"

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
