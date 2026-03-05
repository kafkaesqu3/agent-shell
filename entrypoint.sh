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

# --- Install statusline if available ---
if [ -f /opt/claude-config/statusline.sh ] && [ ! -f /root/.claude/statusline.sh ]; then
  cp /opt/claude-config/statusline.sh /root/.claude/statusline.sh
  chmod +x /root/.claude/statusline.sh
fi

# --- Conditionally strip browser MCP servers if not in browsing image ---
if ! command -v chromium &>/dev/null && [ -f /root/.claude/settings.json ]; then
  # Remove puppeteer and playwright entries since browser isn't available
  jq 'del(.mcpServers.puppeteer, .mcpServers.playwright)' /root/.claude/settings.json > /tmp/settings.json.tmp \
    && mv /tmp/settings.json.tmp /root/.claude/settings.json 2>/dev/null || true
fi

# --- Lock down permissions on .claude directory ---
chmod -R 700 /root/.claude 2>/dev/null || true

# --- Hand off to the requested command ---
exec "$@"
