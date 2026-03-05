#!/bin/bash
# AI Agent Shell - Local Install Script
# Configures the host Claude Code environment to match this repository's
# best-practices config: MCP servers, statusline, CLAUDE.md, and PATH setup.
#
# Usage: ./install.sh [--docker-only] [--config-only] [--path-only]
#   No flags = full install (config + tools + Docker build + PATH setup)

set -e

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
DO_DOCKER=true
DO_PATH=true

for arg in "$@"; do
  case "$arg" in
    --docker-only) DO_CONFIG=false; DO_TOOLS=false; DO_PATH=false ;;
    --config-only) DO_TOOLS=false; DO_DOCKER=false; DO_PATH=false ;;
    --path-only)   DO_CONFIG=false; DO_TOOLS=false; DO_DOCKER=false ;;
    --no-docker)   DO_DOCKER=false ;;
    --help|-h)
      echo "Usage: ./install.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --docker-only   Only build Docker images"
      echo "  --config-only   Only install Claude Code config"
      echo "  --path-only     Only set up PATH for launcher scripts"
      echo "  --no-docker     Skip Docker build"
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
# 1. Claude Code Configuration
###############################################################################
if [ "$DO_CONFIG" = true ]; then
  echo -e "${BOLD}--- Claude Code Configuration ---${NC}"

  mkdir -p "$CLAUDE_HOME"

  # --- settings.json: merge MCP servers ---
  REPO_SETTINGS="$SCRIPT_DIR/claude-config/settings.json"
  HOST_SETTINGS="$CLAUDE_HOME/settings.json"

  if [ -f "$HOST_SETTINGS" ]; then
    info "Merging MCP servers into existing $HOST_SETTINGS"
    # Deep merge: repo mcpServers into host, preserving host's other keys
    jq -s '.[0] * { mcpServers: (.[0].mcpServers // {} ) * .[1].mcpServers }' \
      "$HOST_SETTINGS" "$REPO_SETTINGS" > /tmp/claude-settings-merged.json

    # Replace env placeholders with actual env vars if set
    MERGED=/tmp/claude-settings-merged.json
    if [ -n "$GITHUB_TOKEN" ]; then
      sed -i "s|__GITHUB_TOKEN__|${GITHUB_TOKEN}|g" "$MERGED"
    fi
    if [ -n "$BRAVE_API_KEY" ]; then
      sed -i "s|__BRAVE_API_KEY__|${BRAVE_API_KEY}|g" "$MERGED"
    fi

    cp "$HOST_SETTINGS" "$HOST_SETTINGS.bak"
    mv "$MERGED" "$HOST_SETTINGS"
    ok "MCP servers merged (backup at settings.json.bak)"
  else
    info "No existing settings.json found, copying from repo"
    cp "$REPO_SETTINGS" "$HOST_SETTINGS"

    # Patch placeholders
    if [ -n "$GITHUB_TOKEN" ]; then
      sed -i "s|__GITHUB_TOKEN__|${GITHUB_TOKEN}|g" "$HOST_SETTINGS"
    fi
    if [ -n "$BRAVE_API_KEY" ]; then
      sed -i "s|__BRAVE_API_KEY__|${BRAVE_API_KEY}|g" "$HOST_SETTINGS"
    fi
    ok "settings.json installed"
  fi

  # --- CLAUDE.md ---
  REPO_CLAUDE_MD="$SCRIPT_DIR/claude-config/CLAUDE.md"
  HOST_CLAUDE_MD="$CLAUDE_HOME/CLAUDE.md"

  if [ -f "$HOST_CLAUDE_MD" ]; then
    # Check if the repo line is already present
    if grep -qF "$(cat "$REPO_CLAUDE_MD")" "$HOST_CLAUDE_MD" 2>/dev/null; then
      ok "CLAUDE.md already contains repo instructions"
    else
      info "Appending repo CLAUDE.md instructions to existing file"
      echo "" >> "$HOST_CLAUDE_MD"
      echo "# --- AI Agent Shell defaults ---" >> "$HOST_CLAUDE_MD"
      cat "$REPO_CLAUDE_MD" >> "$HOST_CLAUDE_MD"
      ok "CLAUDE.md updated"
    fi
  else
    cp "$REPO_CLAUDE_MD" "$HOST_CLAUDE_MD"
    ok "CLAUDE.md installed"
  fi

  # --- statusline.sh ---
  REPO_STATUSLINE="$SCRIPT_DIR/claude-config/statusline.sh"
  HOST_STATUSLINE="$CLAUDE_HOME/statusline.sh"

  if [ -f "$REPO_STATUSLINE" ]; then
    cp "$REPO_STATUSLINE" "$HOST_STATUSLINE"
    chmod +x "$HOST_STATUSLINE"
    ok "statusline.sh installed to $HOST_STATUSLINE"
  else
    warn "No statusline.sh found in repo"
  fi

  echo ""
fi

###############################################################################
# 2. Install local MCP server dependencies
###############################################################################
if [ "$DO_TOOLS" = true ]; then
  echo -e "${BOLD}--- Installing MCP Server Dependencies ---${NC}"

  # Check for Node.js
  if ! command -v node &>/dev/null; then
    err "Node.js not found. Please install Node.js 18+ first."
    exit 1
  fi
  ok "Node.js $(node --version) found"

  # Check for npm
  if ! command -v npm &>/dev/null; then
    err "npm not found."
    exit 1
  fi

  info "Installing MCP servers globally via npm..."
  npm install -g \
    @modelcontextprotocol/server-filesystem \
    @modelcontextprotocol/server-github \
    mcp-server-sqlite-npx \
    @modelcontextprotocol/server-brave-search \
    @modelcontextprotocol/server-sequential-thinking \
    @upstash/context7-mcp \
    @modelcontextprotocol/server-puppeteer \
    @playwright/mcp 2>&1 | tail -5
  ok "MCP servers installed"

  # Python MCP fetch server
  if command -v pip3 &>/dev/null; then
    info "Installing Python MCP fetch server..."
    pip3 install --quiet mcp-server-fetch 2>&1 | tail -3
    ok "mcp-server-fetch installed"
  elif command -v pip &>/dev/null; then
    info "Installing Python MCP fetch server..."
    pip install --quiet mcp-server-fetch 2>&1 | tail -3
    ok "mcp-server-fetch installed"
  else
    warn "pip not found - skipping mcp-server-fetch (Python). Install Python 3 for full functionality."
  fi

  echo ""
fi

###############################################################################
# 3. Docker Build
###############################################################################
if [ "$DO_DOCKER" = true ]; then
  echo -e "${BOLD}--- Building Docker Images ---${NC}"

  if ! command -v docker &>/dev/null; then
    err "Docker not found. Please install Docker first."
    exit 1
  fi

  if ! docker info &>/dev/null 2>&1; then
    err "Docker daemon not running. Please start Docker."
    exit 1
  fi

  info "Building ai-agent:latest (base image)..."
  docker build -t ai-agent:latest --target base "$SCRIPT_DIR"
  ok "ai-agent:latest built"

  echo ""
  read -p "Also build browsing variant (includes Chromium, larger image)? [y/N] " -n 1 -r
  echo ""
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    info "Building ai-agent-browsing:latest..."
    docker build -t ai-agent-browsing:latest --target browsing "$SCRIPT_DIR"
    ok "ai-agent-browsing:latest built"
  fi

  echo ""
fi

###############################################################################
# 4. PATH Setup for Launcher Scripts
###############################################################################
if [ "$DO_PATH" = true ]; then
  echo -e "${BOLD}--- PATH Setup ---${NC}"

  mkdir -p "$CONFIG_DIR"

  # Determine the user's shell profile
  SHELL_NAME=$(basename "$SHELL")
  case "$SHELL_NAME" in
    zsh)  PROFILE="$HOME/.zshrc" ;;
    bash) PROFILE="$HOME/.bashrc" ;;
    *)    PROFILE="$HOME/.profile" ;;
  esac

  # Create symlinks in ~/.local/bin (standard user bin dir)
  LOCAL_BIN="$HOME/.local/bin"
  mkdir -p "$LOCAL_BIN"

  ln -sf "$SCRIPT_DIR/ai-agent.sh" "$LOCAL_BIN/ai-agent"
  chmod +x "$SCRIPT_DIR/ai-agent.sh"
  ok "Symlinked ai-agent -> $LOCAL_BIN/ai-agent"

  # Check if ~/.local/bin is in PATH
  if ! echo "$PATH" | grep -q "$LOCAL_BIN"; then
    info "Adding $LOCAL_BIN to PATH in $PROFILE"
    echo "" >> "$PROFILE"
    echo "# AI Agent Shell - added by install.sh" >> "$PROFILE"
    echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> "$PROFILE"
    ok "PATH updated in $PROFILE (restart shell or run: source $PROFILE)"
  else
    ok "$LOCAL_BIN already in PATH"
  fi

  # Copy .env template if none exists
  if [ ! -f "$CONFIG_DIR/.env" ]; then
    cp "$SCRIPT_DIR/.env.example" "$CONFIG_DIR/.env"
    info "Copied .env template to $CONFIG_DIR/.env - edit with your API keys"
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
  echo -e "  ${BLUE}1.${NC} Review ~/.claude/settings.json - replace any __PLACEHOLDER__ values"
  echo -e "     with your actual API keys, or set them in your environment."
fi
if [ "$DO_PATH" = true ]; then
  echo -e "  ${BLUE}2.${NC} Edit $CONFIG_DIR/.env with your API keys"
  echo -e "  ${BLUE}3.${NC} Run 'ai-agent' from any project directory to launch the container"
fi
if [ "$DO_DOCKER" = true ]; then
  echo -e "  ${BLUE}4.${NC} Test: cd /some/project && ai-agent"
fi
echo ""
echo -e "  ${YELLOW}Tip:${NC} On Windows, add this directory to your PATH manually"
echo -e "  and use ai-agent.ps1 instead."
echo ""
