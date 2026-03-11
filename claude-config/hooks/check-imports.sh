#!/usr/bin/env bash
set -euo pipefail
# PreToolUse hook for Write and Edit: block relative imports

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name')
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path')

if [ "$TOOL" = "Write" ]; then
  CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content')
elif [ "$TOOL" = "Edit" ]; then
  CONTENT=$(echo "$INPUT" | jq -r '.tool_input.new_string')
else
  exit 0
fi

case "$FILE" in
  *.py)
    if echo "$CONTENT" | grep -qE '^from [.][.]'; then
      echo "BLOCKED: Use absolute imports, not relative (..) imports" >&2
      exit 2
    fi
    ;;
  *.ts|*.js|*.tsx|*.jsx)
    if echo "$CONTENT" | grep -qE 'from ['"'"'"][.][.]'; then
      echo "BLOCKED: Use absolute imports, not relative (../) imports" >&2
      exit 2
    fi
    ;;
esac
exit 0
