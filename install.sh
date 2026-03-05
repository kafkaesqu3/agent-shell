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
    info "Merging MCP servers into existing $HOST_SETTINGS"
    jq -s '.[0] * { mcpServers: (.[0].mcpServers // {}) * .[1].mcpServers }' \
      "$HOST_SETTINGS" "$REPO_SETTINGS" > /tmp/claude-settings-merged.json

    MERGED=/tmp/claude-settings-merged.json
    [ -n "${GITHUB_TOKEN:-}" ] && sed -i "s|__GITHUB_TOKEN__|${GITHUB_TOKEN}|g" "$MERGED"
    [ -n "${BRAVE_API_KEY:-}" ] && sed -i "s|__BRAVE_API_KEY__|${BRAVE_API_KEY}|g" "$MERGED"

    cp "$HOST_SETTINGS" "${HOST_SETTINGS}.bak"
    mv "$MERGED" "$HOST_SETTINGS"
    ok "MCP servers merged (backup at settings.json.bak)"
  else
    info "No existing settings.json — copying from repo"
    cp "$REPO_SETTINGS" "$HOST_SETTINGS"
    [ -n "${GITHUB_TOKEN:-}" ] && sed -i "s|__GITHUB_TOKEN__|${GITHUB_TOKEN}|g" "$HOST_SETTINGS"
    [ -n "${BRAVE_API_KEY:-}" ] && sed -i "s|__BRAVE_API_KEY__|${BRAVE_API_KEY}|g" "$HOST_SETTINGS"
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
      info "Appending repo CLAUDE.md instructions to existing file"
      { echo ""; echo "# --- AI Agent Shell defaults ---"; cat "$REPO_CLAUDE_MD"; } >> "$HOST_CLAUDE_MD"
      ok "CLAUDE.md updated"
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

  # Node.js — required for Claude Code and all npm MCP servers
  if ! command -v node &>/dev/null; then
    warn "Node.js not found — attempting install..."
    if command -v apt-get &>/dev/null; then
      curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
      sudo apt-get install -y nodejs
    elif command -v brew &>/dev/null; then
      brew install node@22
    else
      err "Cannot auto-install Node.js. Install Node.js 18+ manually then re-run."
      exit 1
    fi
  fi
  ok "Node.js $(node --version)"

  # Claude Code
  info "Installing Claude Code..."
  npm install -g @anthropic-ai/claude-code 2>&1 | tail -2
  ok "Claude Code $(claude --version 2>/dev/null)"

  # MCP servers (npm)
  info "Installing MCP servers (npm)..."
  npm install -g \
    @modelcontextprotocol/server-filesystem \
    @modelcontextprotocol/server-github \
    mcp-server-sqlite-npx \
    @modelcontextprotocol/server-brave-search \
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
  echo -e "    Replace __GITHUB_TOKEN__ and __BRAVE_API_KEY__ if not set as env vars"
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
