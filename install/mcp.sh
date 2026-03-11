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
    @modelcontextprotocol/server-puppeteer \
    @playwright/mcp 2>&1 | tail -3
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

  echo ""
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/install/common.sh"
  install_mcp
fi
