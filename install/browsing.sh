#!/usr/bin/env bash
# install_browsing: install Chromium, browser MCP servers, and Python browser deps.
# Mirrors the Docker 'browsing' stage for host/VPS installs.
set -euo pipefail
# shellcheck source=install/common.sh
[[ -z "${SCRIPT_DIR:-}" ]] && source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/install/common.sh"

install_browsing() {
  echo -e "${BOLD}--- Installing Browsing Components ---${NC}"

  # --- Chromium (system browser) ---
  local os
  os=$(detect_os)
  if cmd_exists chromium-browser || cmd_exists chromium || cmd_exists google-chrome; then
    ok "Chromium already installed"
  else
    info "Installing Chromium..."
    case "$os" in
      ubuntu)
        sudo apt-get update -qq
        sudo apt-get install -y --no-install-recommends chromium-browser chromium-chromedriver
        ;;
      macos)
        if cmd_exists brew; then
          brew install --cask chromium
        else
          err "Homebrew not found — install Chromium manually from https://www.chromium.org/getting-involved/download-chromium"
          return 1
        fi
        ;;
      fedora)
        sudo dnf install -y chromium
        ;;
      arch)
        sudo pacman -Sy --noconfirm chromium
        ;;
      *)
        err "Unsupported OS '$os' — install Chromium manually then re-run"
        return 1
        ;;
    esac
    ok "Chromium installed"
  fi

  # Resolve the chromium binary path for later use
  local chromium_bin
  chromium_bin=$(command -v chromium-browser 2>/dev/null \
    || command -v chromium 2>/dev/null \
    || command -v google-chrome 2>/dev/null)

  # --- Browser MCP servers (npm) ---
  info "Installing browser MCP servers (npm)..."
  npm install -g \
    @modelcontextprotocol/server-puppeteer \
    @playwright/mcp 2>&1 | tail -3
  ok "Browser MCP npm packages installed"

  # --- Playwright managed browser binaries ---
  info "Installing Playwright browser binaries..."
  npx playwright install --with-deps chromium 2>&1 | tail -5
  ok "Playwright browser binaries installed"

  # --- Python browser deps ---
  if cmd_exists python3; then
    local browsing_venv="$HOME/.local/share/mcp-browsing-venv"
    info "Installing Python browser deps in venv at $browsing_venv..."
    python3 -m venv "$browsing_venv"
    "$browsing_venv/bin/pip" install --quiet playwright beautifulsoup4
    ok "Python playwright + beautifulsoup4 installed"
  else
    warn "python3 not found — skipping Python browser deps"
  fi

  # --- Register browser MCP servers in ~/.claude.json ---
  local claude_json="$HOME/.claude.json"
  if cmd_exists jq; then
    [ -f "$claude_json" ] || echo '{}' > "$claude_json"
    local browser_mcps
    browser_mcps=$(jq -n '{
      puppeteer: {
        command: "npx",
        args: ["-y", "@modelcontextprotocol/server-puppeteer"]
      },
      playwright: {
        command: "npx",
        args: ["-y", "@playwright/mcp", "--headless"]
      }
    }')
    jq --argjson bmcp "$browser_mcps" '.mcpServers += $bmcp' \
      "$claude_json" > /tmp/claude-json-browser.json \
      && mv /tmp/claude-json-browser.json "$claude_json"
    ok "Browser MCP servers (puppeteer, playwright) registered in $claude_json"
  else
    warn "jq not found — skipping browser MCP registration"
  fi

  echo ""
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/install/common.sh"
  install_browsing
fi
