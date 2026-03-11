#!/usr/bin/env bash
set -euo pipefail
# PostToolUse hook for Write and Edit: lint shell scripts and workflow files

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path')

case "$FILE" in
  *.sh)
    # Warn if set -euo pipefail is missing
    if [ -f "$FILE" ] && ! head -5 "$FILE" | grep -q 'set -euo pipefail'; then
      echo "WARNING: $FILE is missing 'set -euo pipefail' near the top" >&2
    fi
    # Run shellcheck if available
    if command -v shellcheck >/dev/null 2>&1 && [ -f "$FILE" ]; then
      RESULT=$(shellcheck "$FILE" 2>&1 || true)
      if [ -n "$RESULT" ]; then
        echo "shellcheck:" >&2
        echo "$RESULT" >&2
      fi
    fi
    ;;
  */.github/workflows/*.yml|*/.github/workflows/*.yaml)
    if command -v actionlint >/dev/null 2>&1 && [ -f "$FILE" ]; then
      RESULT=$(actionlint "$FILE" 2>&1 || true)
      if [ -n "$RESULT" ]; then
        echo "actionlint:" >&2
        echo "$RESULT" >&2
      fi
    fi
    ;;
esac
exit 0
