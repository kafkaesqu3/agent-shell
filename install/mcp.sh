#!/usr/bin/env bash
# install_mcp: install MCP servers (npm globals + mcp-server-fetch venv)
set -euo pipefail
# shellcheck source=install/common.sh
[[ -z "${SCRIPT_DIR:-}" ]] && source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/install/common.sh"

install_mcp() {
  echo -e "${BOLD}--- Installing MCP Servers ---${NC}"

  info "Installing MCP servers (npm)..."
  npm install -g \
    @modelcontextprotocol/server-filesystem \
    @modelcontextprotocol/server-github \
    mcp-server-sqlite-npx \
    brave-search-mcp \
    @modelcontextprotocol/server-sequential-thinking \
    @upstash/context7-mcp \
    exa-mcp-server 2>&1 | tail -3
  ok "npm MCP servers installed"

  # mcp-server-fetch — isolated venv avoids Ubuntu 24.04 system pip conflict
  if cmd_exists python3; then
    local fetch_venv="$HOME/.local/share/mcp-fetch-venv"
    info "Installing mcp-server-fetch in venv at $fetch_venv..."
    python3 -m venv "$fetch_venv"
    "$fetch_venv/bin/pip" install --quiet mcp-server-fetch
    mkdir -p "$LOCAL_BIN"
    ln -sf "$fetch_venv/bin/mcp-server-fetch" "$LOCAL_BIN/mcp-server-fetch"
    ok "mcp-server-fetch → $LOCAL_BIN/mcp-server-fetch"
  else
    warn "python3 not found — skipping mcp-server-fetch"
  fi

  # --- Register MCP servers into ~/.claude.json (user scope) ---
  # Claude Code reads MCP servers from ~/.claude.json, not settings.json.
  # mcp-servers.json is the source of truth (native .mcp.json format).
  # Project-specific .mcp.json files in project roots still work alongside these.
  local mcp_file="$SCRIPT_DIR/claude-config/mcp-servers.json"
  local claude_json="$HOME/.claude.json"
  if [ -f "$mcp_file" ] && cmd_exists jq; then
    [ -f "$claude_json" ] || echo '{}' > "$claude_json"

    # Substitute known placeholders, then drop any entry still containing one
    local mcp_raw
    mcp_raw=$(cat "$mcp_file")
    [ -n "${BRIGHTDATA_API_KEY:-}" ] && \
      mcp_raw=$(printf '%s' "$mcp_raw" | sed "s|__BRIGHTDATA_API_KEY__|${BRIGHTDATA_API_KEY}|g")
    [ -n "${EXA_API_KEY:-}" ] && \
      mcp_raw=$(printf '%s' "$mcp_raw" | sed "s|__EXA_API_KEY__|${EXA_API_KEY}|g")

    local mcp_servers
    mcp_servers=$(printf '%s' "$mcp_raw" | jq '
      .mcpServers |
      to_entries |
      map(select(.value | tostring | test("__[A-Z_]+__") | not)) |
      from_entries
    ')

    # Write to user-scope top-level mcpServers.
    # Also remove empty mcpServers ({}) from project entries so they don't shadow globals.
    jq --argjson mcp "$mcp_servers" '
      .mcpServers = $mcp |
      if .projects then
        .projects |= with_entries(
          if (.value.mcpServers // {}) == {} then del(.value.mcpServers) else . end
        )
      else . end
    ' "$claude_json" > /tmp/claude-json-mcp.json \
      && mv /tmp/claude-json-mcp.json "$claude_json"
    ok "MCP servers registered in $claude_json"
  else
    warn "mcp-servers.json or jq not found — skipping MCP server registration"
  fi

  echo ""
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/install/common.sh"
  install_mcp
fi
