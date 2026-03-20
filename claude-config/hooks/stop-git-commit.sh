#!/usr/bin/env bash
set -uo pipefail
# Stop hook: git-init if needed, then commit all changes after each Claude turn.
# Fires once when Claude finishes its full response — covers all edits made
# during that turn in a single commit.

INPUT=$(cat)
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty')

# Git-init if not already a repo (skip on filesystems that don't support chmod,
# e.g. Windows/WSL bind mounts — git init will fail with a lock/chmod error)
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  git init || exit 0
fi

# Stage everything
git add -A

# Nothing staged — nothing changed this turn
if git diff --cached --quiet; then
  exit 0
fi

# Collect changed file summary for commit body
STAT=$(git diff --cached --stat 2>/dev/null | tail -1)
FILES=$(git diff --cached --name-only 2>/dev/null | head -20 | tr '\n' ' ' | sed 's/[[:space:]]*$//')

# Derive commit message from the last user message in the transcript
MSG=""
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
  LAST=$(jq -r '
    [.[] | select(.role == "user")] | last |
    .content |
    if type == "array" then map(select(.type == "text") | .text) | join(" ")
    else .
    end
  ' "$TRANSCRIPT" 2>/dev/null || true)
  if [ -n "$LAST" ]; then
    # Trim to 72 chars, collapse whitespace
    MSG=$(echo "$LAST" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g; s/^[[:space:]]*//; s/[[:space:]]*$//' | cut -c1-72)
  fi
fi

# Fallback: use changed files as subject
if [ -z "$MSG" ]; then
  MSG="claude: update $FILES"
  MSG=$(echo "$MSG" | cut -c1-72)
fi

git commit \
  -m "$MSG" \
  -m "Changed: $FILES" \
  -m "$STAT" \
  >/dev/null 2>&1 || true

exit 0
