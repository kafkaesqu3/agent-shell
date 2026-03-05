#!/bin/bash
set -e

# Config files are always overwritten from the baked image so that rebuilding
# the image is sufficient to pick up changes from claude-config/ in the repo.
# Only credentials and session state (history, projects) are preserved.

# --- Config files: always sync from image ---
cp /opt/claude-config/CLAUDE.md /home/agent/.claude/CLAUDE.md
cp /opt/claude-config/settings.json /home/agent/.claude/settings.json
if [ -f /opt/claude-config/statusline.sh ]; then
  cp /opt/claude-config/statusline.sh /home/agent/.claude/statusline.sh
  chmod +x /home/agent/.claude/statusline.sh
fi

# --- Patch MCP env var placeholders in settings.json ---
if [ -n "$GITHUB_TOKEN" ]; then
  sed -i "s|__GITHUB_TOKEN__|${GITHUB_TOKEN}|g" /home/agent/.claude/settings.json
fi
if [ -n "$BRAVE_API_KEY" ]; then
  sed -i "s|__BRAVE_API_KEY__|${BRAVE_API_KEY}|g" /home/agent/.claude/settings.json
fi

# --- Write credentials file if token provided and file missing ---
if [ -n "$CLAUDE_CODE_OAUTH_TOKEN" ] && [ ! -f /home/agent/.claude/.credentials.json ]; then
  cat > /home/agent/.claude/.credentials.json <<EOF
{
  "claudeAiOauth": {
    "token": "${CLAUDE_CODE_OAUTH_TOKEN}"
  }
}
EOF
  chmod 600 /home/agent/.claude/.credentials.json
fi

# --- Conditionally strip browser MCP servers if not in browsing image ---
if ! command -v chromium &>/dev/null && [ -f /home/agent/.claude/settings.json ]; then
  # Remove puppeteer and playwright entries since browser isn't available
  jq 'del(.mcpServers.puppeteer, .mcpServers.playwright)' /home/agent/.claude/settings.json > /tmp/settings.json.tmp \
    && mv /tmp/settings.json.tmp /home/agent/.claude/settings.json 2>/dev/null || true
fi

# --- Lock down permissions on .claude directory ---
chmod -R 700 /home/agent/.claude 2>/dev/null || true

# --- Hand off to the requested command ---
exec "$@"
