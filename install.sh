#!/bin/bash
# AI Agent Shell - Local Install Script
# Configures the host Claude Code environment to match this repository's
# best-practices config: Claude Code, MCP servers, statusline, CLAUDE.md, PATH.
#
# Usage: ./install.sh [OPTIONS]
#   No flags = full install (config + tools + Docker build + PATH setup)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_HOME="$HOME/.claude"
CONFIG_DIR="$HOME/.config/ai-agent"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()   { echo -e "${RED}[ERROR]${NC} $1"; }

# Parse flags
DO_CONFIG=true
DO_TOOLS=true
DO_DOCKER=false   # Off by default — most useful for VPS/host installs
DO_PATH=true

for arg in "$@"; do
  case "$arg" in
    --docker)       DO_DOCKER=true ;;
    --docker-only)  DO_CONFIG=false; DO_TOOLS=false; DO_PATH=false; DO_DOCKER=true ;;
    --config-only)  DO_TOOLS=false; DO_DOCKER=false; DO_PATH=false ;;
    --path-only)    DO_CONFIG=false; DO_TOOLS=false; DO_DOCKER=false ;;
    --no-tools)     DO_TOOLS=false ;;
    --no-path)      DO_PATH=false ;;
    --help|-h)
      echo "Usage: ./install.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  (no flags)      Full install: config + tools + PATH (no Docker)"
      echo "  --docker        Also build Docker images"
      echo "  --docker-only   Only build Docker images"
      echo "  --config-only   Only install Claude Code config files"
      echo "  --path-only     Only set up PATH for launcher scripts"
      echo "  --no-tools      Skip tool installation"
      echo "  --no-path       Skip PATH setup"
      echo "  -h, --help      Show this help"
      exit 0
      ;;
  esac
done

echo -e "${BOLD}${BLUE}"
echo "╔══════════════════════════════════════╗"
echo "║    AI Agent Shell - Installer        ║"
echo "╚══════════════════════════════════════╝"
echo -e "${NC}"

###############################################################################
# 1. Claude Code Configuration (CLAUDE.md, settings.json, statusline)
###############################################################################
if [ "$DO_CONFIG" = true ]; then
  echo -e "${BOLD}--- Claude Code Configuration ---${NC}"

  mkdir -p "$CLAUDE_HOME"

  # --- settings.json: merge MCP servers ---
  REPO_SETTINGS="$SCRIPT_DIR/claude-config/settings.json"
  HOST_SETTINGS="$CLAUDE_HOME/settings.json"

  if [ -f "$HOST_SETTINGS" ]; then
    info "Merging repo settings into existing $HOST_SETTINGS"
    # Repo is the base; preserve user-specific overrides: model, plugins, UI prefs, attribution.
    # For mcpServers, repo provides the schema but host values win — preserves already-substituted
    # tokens on re-runs so __PLACEHOLDER__ strings never overwrite real tokens.
    jq -s '
      .[1] * {
        mcpServers: (.[1].mcpServers * (.[0].mcpServers // {})),
        model:                 (.[0].model // .[1].model),
        enabledPlugins:        (.[0].enabledPlugins // {}),
        clearTerminalOnLaunch: (.[0].clearTerminalOnLaunch // .[1].clearTerminalOnLaunch),
        attribution:           (.[0].attribution // .[1].attribution)
      }
    ' "$HOST_SETTINGS" "$REPO_SETTINGS" > /tmp/claude-settings-merged.json

    MERGED=/tmp/claude-settings-merged.json
    [ -n "${BRIGHTDATA_API_KEY:-}" ] && sed -i "s|__BRIGHTDATA_API_KEY__|${BRIGHTDATA_API_KEY}|g" "$MERGED"

    cp "$HOST_SETTINGS" "${HOST_SETTINGS}.bak"
    mv "$MERGED" "$HOST_SETTINGS"
    ok "Settings merged (backup at settings.json.bak)"
  else
    info "No existing settings.json — copying from repo"
    cp "$REPO_SETTINGS" "$HOST_SETTINGS"
    [ -n "${BRIGHTDATA_API_KEY:-}" ] && sed -i "s|__BRIGHTDATA_API_KEY__|${BRIGHTDATA_API_KEY}|g" "$HOST_SETTINGS"
    ok "settings.json installed"
  fi

  # --- CLAUDE.md: append if not already present ---
  REPO_CLAUDE_MD="$SCRIPT_DIR/claude-config/CLAUDE.md"
  HOST_CLAUDE_MD="$CLAUDE_HOME/CLAUDE.md"
  MARKER="# Global Development Standards"

  if [ -f "$HOST_CLAUDE_MD" ]; then
    if grep -qF "$MARKER" "$HOST_CLAUDE_MD" 2>/dev/null; then
      ok "CLAUDE.md already contains repo instructions"
    else
      # Host CLAUDE.md predates this repo — replace with repo version (superset)
      info "Replacing CLAUDE.md with repo version (backup at CLAUDE.md.bak)"
      cp "$HOST_CLAUDE_MD" "${HOST_CLAUDE_MD}.bak"
      cp "$REPO_CLAUDE_MD" "$HOST_CLAUDE_MD"
      ok "CLAUDE.md replaced"
    fi
  else
    cp "$REPO_CLAUDE_MD" "$HOST_CLAUDE_MD"
    ok "CLAUDE.md installed"
  fi

  # --- statusline.sh ---
  REPO_STATUSLINE="$SCRIPT_DIR/claude-config/statusline.sh"
  if [ -f "$REPO_STATUSLINE" ]; then
    cp "$REPO_STATUSLINE" "$CLAUDE_HOME/statusline.sh"
    chmod +x "$CLAUDE_HOME/statusline.sh"
    ok "statusline.sh installed to $CLAUDE_HOME/statusline.sh"
  else
    warn "statusline.sh not found in repo — skipping"
  fi

  echo ""
fi

###############################################################################
# 2. Install Claude Code + MCP server dependencies
###############################################################################
if [ "$DO_TOOLS" = true ]; then
  echo -e "${BOLD}--- Installing Tools ---${NC}"

  # nvm + Node.js — required for Claude Code and all npm MCP servers
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  if [ ! -s "$NVM_DIR/nvm.sh" ]; then
    info "Installing nvm..."
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
    # shellcheck source=/dev/null
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    ok "nvm installed"
  else
    # shellcheck source=/dev/null
    \. "$NVM_DIR/nvm.sh"
    ok "nvm already installed ($(nvm --version))"
  fi

  if ! nvm ls 22 &>/dev/null; then
    info "Installing Node.js 22 via nvm..."
    nvm install 22
  fi
  nvm use 22
  nvm alias default 22
  ok "Node.js $(node --version)"

  # Claude Code (official installer — npm method is deprecated)
  info "Installing Claude Code..."
  curl -fsSL https://claude.ai/install.sh | bash 2>&1 | tail -3
  ok "Claude Code installed"

  # MCP servers (npm)
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

  # mcp-server-fetch (Python) — isolated venv avoids Ubuntu 24.04 system pip conflict
  if command -v python3 &>/dev/null; then
    FETCH_VENV="$HOME/.local/share/mcp-fetch-venv"
    info "Installing mcp-server-fetch in venv at $FETCH_VENV..."
    python3 -m venv "$FETCH_VENV"
    "$FETCH_VENV/bin/pip" install --quiet mcp-server-fetch
    mkdir -p "$HOME/.local/bin"
    ln -sf "$FETCH_VENV/bin/mcp-server-fetch" "$HOME/.local/bin/mcp-server-fetch"
    ok "mcp-server-fetch → $HOME/.local/bin/mcp-server-fetch"
  else
    warn "python3 not found — skipping mcp-server-fetch"
  fi

  echo ""
fi

###############################################################################
# 3. Docker Build (opt-in with --docker)
###############################################################################
if [ "$DO_DOCKER" = true ]; then
  echo -e "${BOLD}--- Building Docker Images ---${NC}"

  if ! command -v docker &>/dev/null; then
    err "Docker not found. Install Docker then re-run with --docker."
    exit 1
  fi
  if ! docker info &>/dev/null 2>&1; then
    err "Docker daemon not running."
    exit 1
  fi

  info "Building ai-agent:latest (base)..."
  docker build -t ai-agent:latest --target base "$SCRIPT_DIR"
  ok "ai-agent:latest built"

  echo ""
  read -rp "Also build browsing variant (Chromium, ~2x larger)? [y/N] " -n 1
  echo ""
  if [[ ${REPLY:-n} =~ ^[Yy]$ ]]; then
    info "Building ai-agent-browsing:latest..."
    docker build -t ai-agent-browsing:latest --target browsing "$SCRIPT_DIR"
    ok "ai-agent-browsing:latest built"
  fi

  echo ""
fi

###############################################################################
# 4. PATH Setup for launcher scripts
###############################################################################
if [ "$DO_PATH" = true ]; then
  echo -e "${BOLD}--- PATH Setup ---${NC}"

  mkdir -p "$CONFIG_DIR"

  SHELL_NAME=$(basename "${SHELL:-bash}")
  case "$SHELL_NAME" in
    zsh)  PROFILE="$HOME/.zshrc" ;;
    bash) PROFILE="$HOME/.bashrc" ;;
    *)    PROFILE="$HOME/.profile" ;;
  esac

  LOCAL_BIN="$HOME/.local/bin"
  mkdir -p "$LOCAL_BIN"

  chmod +x "$SCRIPT_DIR/ai-agent.sh"
  ln -sf "$SCRIPT_DIR/ai-agent.sh" "$LOCAL_BIN/ai-agent"
  ok "Symlinked ai-agent → $LOCAL_BIN/ai-agent"

  # --- claude wrapper: route to container by default, --host for local ---
  chmod +x "$SCRIPT_DIR/claude-wrapper.sh"
  REAL_CLAUDE="$(command -v claude 2>/dev/null || true)"
  if [ -n "$REAL_CLAUDE" ]; then
    if grep -q "claude-host" "$REAL_CLAUDE" 2>/dev/null; then
      # Already our wrapper — update it in place
      cp "$SCRIPT_DIR/claude-wrapper.sh" "$REAL_CLAUDE"
      ok "claude wrapper updated"
    else
      # First install: save real binary as claude-host, install wrapper as claude
      CLAUDE_DIR="$(dirname "$REAL_CLAUDE")"
      cp "$REAL_CLAUDE" "$CLAUDE_DIR/claude-host"
      chmod +x "$CLAUDE_DIR/claude-host"
      cp "$SCRIPT_DIR/claude-wrapper.sh" "$REAL_CLAUDE"
      chmod +x "$REAL_CLAUDE"
      ok "claude wrapper installed (original binary → claude-host)"
    fi
  else
    # claude not yet installed — place wrapper now, claude-host resolved later
    cp "$SCRIPT_DIR/claude-wrapper.sh" "$LOCAL_BIN/claude"
    chmod +x "$LOCAL_BIN/claude"
    warn "claude not found — wrapper installed at $LOCAL_BIN/claude (install claude first, then re-run)"
  fi

  if ! echo "$PATH" | grep -q "$LOCAL_BIN"; then
    { echo ""; echo "# AI Agent Shell — added by install.sh"; echo "export PATH=\"\$HOME/.local/bin:\$PATH\""; } >> "$PROFILE"
    ok "PATH updated in $PROFILE (run: source $PROFILE)"
  else
    ok "$LOCAL_BIN already in PATH"
  fi

  # Copy .env template if none exists
  if [ ! -f "$CONFIG_DIR/.env" ]; then
    cp "$SCRIPT_DIR/.env.example" "$CONFIG_DIR/.env"
    info "Copied .env template → $CONFIG_DIR/.env (edit with your API keys)"
  fi

  # --- Print shell snippets for manual addition ---
  echo ""
  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BOLD}Shell config changes required${NC}"
  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo -e "${BOLD}1. ${BLUE}~/.zshrc${NC} or ${BLUE}~/.bashrc${NC}"
  echo -e "   ${YELLOW}Add these lines if not already present:${NC}"
  echo ""
  cat << 'SHELLFUNC'
# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# claude: runs in Docker by default; use --host to run directly on this machine
claude() {
  if [[ "${1:-}" == "--host" ]]; then
    shift
    command claude-host "$@"
  else
    ai-agent claude "$@"
  fi
}
SHELLFUNC

  echo ""
  echo -e "${BOLD}2. ${BLUE}PowerShell profile${NC} (Documents/PowerShell/Microsoft.PowerShell_profile.ps1)"
  echo -e "   ${YELLOW}For Windows users calling claude from PowerShell via WSL:${NC}"
  echo ""
  cat << 'PSFUNC'
# claude: runs in Docker by default; use --host to run directly on WSL
function claude {
  if ($args.Count -gt 0 -and $args[0] -eq "--host") {
    $rest = if ($args.Count -gt 1) { $args[1..($args.Count - 1)] } else { @() }
    wsl claude --host @rest
  } else {
    wsl ai-agent claude @args
  }
}
PSFUNC

  echo ""
  echo -e "  ${YELLOW}Tip:${NC} 'claude' launches in Docker (isolated, reproducible)."
  echo -e "        'claude --host' runs the local binary directly on this machine."
  echo ""
fi

###############################################################################
# Summary
###############################################################################
echo -e "${BOLD}${GREEN}"
echo "╔══════════════════════════════════════╗"
echo "║        Installation Complete         ║"
echo "╚══════════════════════════════════════╝"
echo -e "${NC}"

echo "Next steps:"
if [ "$DO_CONFIG" = true ]; then
  echo -e "  ${BLUE}•${NC} Review ~/.claude/settings.json"
  echo -e "    Set BRIGHTDATA_API_KEY env var (used in BrightData SSE URL)"
fi
if [ "$DO_TOOLS" = true ]; then
  echo -e "  ${BLUE}•${NC} Run 'claude' to authenticate (claude.ai account or ANTHROPIC_API_KEY)"
fi
if [ "$DO_PATH" = true ]; then
  echo -e "  ${BLUE}•${NC} Edit $CONFIG_DIR/.env with your API keys"
  echo -e "  ${BLUE}•${NC} Run 'ai-agent' from any project directory to launch the container"
  echo -e "  ${YELLOW}Tip:${NC} On Windows use ai-agent.ps1 instead"
fi
echo ""
