#!/usr/bin/env bash
set -euo pipefail

# NOTE: This is a dev-only script, intended for use by maintainers of this repo.
# It is not a supported installer. Modifications to it, or requests for
# modifications, will not be approved.
#
# Links all skills in the repository (minus CLAUDE_EXCLUDES below, for
# ~/.claude/skills only) into the local skill directories used by each agent
# harness:
#   - ~/.claude/skills: Claude Code
#   - ~/.agents/skills: Codex and other Agent Skills-compatible harnesses
# Each entry is a symlink into this repo, so a `git pull` is all that's needed
# to keep installed skills up to date.
#
# Platform rules (rules/android, rules/swift) are NOT symlinked into either
# destination — they are injected per-project by rules/detect-rules.sh,
# registered as a SessionStart hook in ~/.claude/settings.json. A global symlink
# would load one platform's rules into every project and contradict the other
# platform's. Cross-platform rules (rules/common) go through the same hook, which
# inlines them in every project.

REPO="$(cd "$(dirname "$0")/.." && pwd)"
DESTS=("$HOME/.claude/skills" "$HOME/.agents/skills")

# Skills NOT linked into ~/.claude/skills because Claude Code already gets their
# content another way. karpathy-guidelines is inlined every session by
# rules/detect-rules.sh (rules/common/karpathy.md), so the skill would only
# duplicate it. Other harnesses don't run that hook, so they keep the link.
CLAUDE_EXCLUDES=(karpathy-guidelines)

# Exit 0 when skill $2 must not be linked into destination $1.
excluded() {
  [ "$1" = "$HOME/.claude/skills" ] || return 1
  local x
  # The ${a[@]+...} form keeps bash 3.2 (macOS) from failing under `set -u`
  # when the list is emptied.
  for x in ${CLAUDE_EXCLUDES[@]+"${CLAUDE_EXCLUDES[@]}"}; do
    [ "$x" = "$2" ] && return 0
  done
  return 1
}

# Collect the repo's skills once, link into every destination. `deprecated/`
# is retired, and `misc/` is kept around but rarely used and not promoted (see
# each bucket's own README): neither belongs in a daily-driver skill
# directory, so both are skipped here, same as everywhere else non-promoted
# skills are kept out. `in-progress/` IS still linked: it's public on purpose,
# feedback wanted, and this local install is exactly where that feedback loop
# runs.
names=()
srcs=()
while IFS= read -r -d '' skill_md; do
  src="$(dirname "$skill_md")"
  names+=("$(basename "$src")")
  srcs+=("$src")
done < <(find "$REPO/skills" -name SKILL.md -not -path '*/node_modules/*' -not -path '*/deprecated/*' -not -path '*/misc/*' -print0)

for DEST in "${DESTS[@]}"; do
  # If $DEST is a symlink that resolves into this repo, we'd end up writing the
  # per-skill symlinks back into the repo's own skills/ tree. Detect and bail
  # out instead of polluting the working copy.
  if [ -L "$DEST" ]; then
    resolved="$(readlink -f "$DEST")"
    case "$resolved" in
      "$REPO"|"$REPO"/*)
        echo "error: $DEST is a symlink into this repo ($resolved)." >&2
        echo "Remove it (rm \"$DEST\") and re-run; the script will recreate it as a real dir." >&2
        exit 1
        ;;
    esac
  fi

  mkdir -p "$DEST"

  for i in "${!names[@]}"; do
    name="${names[$i]}"
    src="${srcs[$i]}"
    target="$DEST/$name"

    # Excluded: drop a link left by an earlier run, but never touch a real
    # directory, which is not ours to delete.
    if excluded "$DEST" "$name"; then
      if [ -L "$target" ]; then
        rm "$target"
        echo "unlinked $name (excluded from $DEST)"
      fi
      continue
    fi

    if [ -e "$target" ] && [ ! -L "$target" ]; then
      rm -rf "$target"
    fi

    ln -sfn "$src" "$target"
    echo "linked $name -> $src ($DEST)"
  done
done
