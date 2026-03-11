#!/usr/bin/env bash
set -euo pipefail
# PostToolUse hook for Write and Edit: auto-init git repo and commit changed files.
# Ensures every file Claude writes/edits is tracked in a local git history.

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Only proceed if we have a real file path
if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
  exit 0
fi

FILE_DIR=$(dirname "$FILE")

# Auto-init: if no git repo found in the file's directory tree, init in $PWD
if ! git -C "$FILE_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  echo "auto-git: no git repo found, initializing in $PWD" >&2
  git -C "$PWD" init
  # Set minimal identity so commits don't fail on unconfigured machines
  git -C "$PWD" config user.email "agent@local"
  git -C "$PWD" config user.name "Claude Agent"
fi

GIT_ROOT=$(git -C "$FILE_DIR" rev-parse --show-toplevel 2>/dev/null || echo "$PWD")

# Stage the specific file
git -C "$GIT_ROOT" add "$FILE"

# Nothing to commit (file was staged but identical to HEAD, or ignored)
if git -C "$GIT_ROOT" diff --cached --quiet; then
  exit 0
fi

RELATIVE_FILE=$(realpath --relative-to="$GIT_ROOT" "$FILE" 2>/dev/null || basename "$FILE")

# Commit — silently ignore failures (e.g. repo has pre-commit hooks that reject the file)
git -C "$GIT_ROOT" commit \
  -m "auto: save $RELATIVE_FILE" \
  --author="Claude Agent <agent@local>" \
  >/dev/null 2>&1 || true

exit 0
