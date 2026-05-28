#!/usr/bin/env bash
set -euo pipefail

# Links all skills in the repository to ~/.claude/skills, and the rules/
# folder to ~/.claude/rules, so that they can be used by the local Claude CLI.

REPO="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$HOME/.claude/skills"
RULES_SRC="$REPO/rules"
RULES_DEST="$HOME/.claude/rules"

# If ~/.claude/skills is a symlink that resolves into this repo, we'd end up
# writing the per-skill symlinks back into the repo's own skills/ tree. Detect
# and bail out instead of polluting the working copy.
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

find "$REPO/skills" -name SKILL.md -not -path '*/node_modules/*' -not -path '*/deprecated/*' -print0 |
while IFS= read -r -d '' skill_md; do
  src="$(dirname "$skill_md")"
  name="$(basename "$src")"
  target="$DEST/$name"

  if [ -e "$target" ] && [ ! -L "$target" ]; then
    rm -rf "$target"
  fi

  ln -sfn "$src" "$target"
  echo "linked $name -> $src"
done

# Link the rules/ folder as a whole to ~/.claude/rules. If a real directory
# already exists there (not a symlink), refuse to clobber it.
if [ -d "$RULES_SRC" ]; then
  if [ -e "$RULES_DEST" ] && [ ! -L "$RULES_DEST" ]; then
    echo "error: $RULES_DEST exists and is not a symlink; refusing to overwrite." >&2
    exit 1
  fi
  ln -sfn "$RULES_SRC" "$RULES_DEST"
  echo "linked rules -> $RULES_SRC"
fi
