#!/bin/bash
set -e

# --- CLAUDE.md layering ---
# Host override takes priority, otherwise fall back to baked default
if [ -f /root/.claude/CLAUDE.md.host ]; then
  cp /root/.claude/CLAUDE.md.host /root/.claude/CLAUDE.md
elif [ ! -f /root/.claude/CLAUDE.md ]; then
  cp /opt/claude-config/CLAUDE.md /root/.claude/CLAUDE.md
fi

# --- settings.json layering ---
if [ -f /root/.claude/settings.json.host ]; then
  cp /root/.claude/settings.json.host /root/.claude/settings.json
elif [ ! -f /root/.claude/settings.json ]; then
  cp /opt/claude-config/settings.json /root/.claude/settings.json
fi

# --- Patch MCP env var placeholders in settings.json ---
if [ -n "$GITHUB_TOKEN" ]; then
  sed -i "s|__GITHUB_TOKEN__|${GITHUB_TOKEN}|g" /root/.claude/settings.json
fi
if [ -n "$BRAVE_API_KEY" ]; then
  sed -i "s|__BRAVE_API_KEY__|${BRAVE_API_KEY}|g" /root/.claude/settings.json
fi

# --- Write credentials file if token provided and file missing ---
if [ -n "$CLAUDE_CODE_OAUTH_TOKEN" ] && [ ! -f /root/.claude/.credentials.json ]; then
  cat > /root/.claude/.credentials.json <<EOF
{
  "claudeAiOauth": {
    "token": "${CLAUDE_CODE_OAUTH_TOKEN}"
  }
}
EOF
  chmod 600 /root/.claude/.credentials.json
fi

# --- Lock down permissions on .claude directory ---
chmod -R 700 /root/.claude 2>/dev/null || true

# --- Hand off to the requested command ---
exec "$@"
