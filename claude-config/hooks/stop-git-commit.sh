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

# Generate commit message from diff using Claude CLI
DIFF=$(git diff --cached 2>/dev/null | head -c 8000)
MSG=$(echo "$DIFF" | claude -p \
  "Write a concise git commit subject line in imperative mood, max 72 chars. \
Describe what was changed at a high level. Output only the commit message, nothing else." \
  2>/dev/null | head -1 | cut -c1-72)

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
