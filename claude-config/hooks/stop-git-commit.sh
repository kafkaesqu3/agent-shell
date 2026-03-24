#!/usr/bin/env bash
set -uo pipefail
# Stop hook: git-init if needed, then commit all changes after each Claude turn.
# Fires once when Claude finishes its full response — covers all edits made
# during that turn in a single commit.

INPUT=$(cat)
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty')

# Skip on filesystems that don't support chmod/file-locking (Windows NTFS bind
# mounts via WSL2 use 9p; WSL1 mounts show as fuseblk/drvfs).
_fstype=$(findmnt -n -o FSTYPE --target . 2>/dev/null)
case "$_fstype" in
  9p|drvfs|cifs|fuseblk) exit 0 ;;
esac

# Git-init if not already a repo. Suppress stderr — on incompatible filesystems
# (e.g. NTFS bind mounts) the chmod on config.lock fails; exit cleanly.
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  git init 2>/dev/null || exit 0
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
