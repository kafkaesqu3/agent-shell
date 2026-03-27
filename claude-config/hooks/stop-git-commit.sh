#!/usr/bin/env bash
set -uo pipefail
# Stop hook: lightweight checkpoint commit after each Claude turn.
# /commit squashes these into a single clean commit with a proper message.

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

git add -A

# Nothing staged — nothing changed this turn
if git diff --cached --quiet; then
  exit 0
fi

git commit -m "claude: session checkpoint" >/dev/null 2>&1 || true

exit 0
