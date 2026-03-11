#!/usr/bin/env bash
set -euo pipefail
# Stop hook: git-init if needed, then commit all changes after each Claude turn.
# Fires once when Claude finishes its full response — covers all edits made
# during that turn in a single commit.

INPUT=$(cat)
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty')

# Git-init if not already a repo
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  git init
  git config user.email "agent@local"
  git config user.name "Claude Agent"
fi

# Stage everything
git add -A

# Nothing staged — nothing changed this turn
if git diff --cached --quiet; then
  exit 0
fi

# Derive commit message from the last user message in the transcript
MSG="claude: session checkpoint"
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

git commit \
  -m "$MSG" \
  --author="Claude Agent <agent@local>" \
  >/dev/null 2>&1 || true

exit 0
