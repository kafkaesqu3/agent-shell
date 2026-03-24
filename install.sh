#!/usr/bin/env bash
# AI Agent Shell — Install Script
# Primary entrypoint for configuring the environment.
#
# Usage: ./install.sh [OPTIONS]
#   (no flags)      Interactive menu
#   --all           Run all steps: config + tools + mcp + agents + docker + path
#   --config        Install Claude Code config files
#   --tools         Install fnm/node/claude + OS dev tools
#   --mcp           Install MCP servers
#   --agents        Install Claude Code agent definitions
#   --docker        Build Docker images
#   --path          Set up symlinks, claude wrapper, shell snippets
#   --skip-docker   Skip Docker build when used with --all
#   -h, --help      Show help
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=install/common.sh
source "$SCRIPT_DIR/install/common.sh"

# Load .env if present — populates API keys for placeholder substitution in install_config
if [[ -f "$SCRIPT_DIR/.env" ]]; then
  # shellcheck disable=SC1091
  set -o allexport; source "$SCRIPT_DIR/.env"; set +o allexport
fi

_banner() {
  echo -e "${BOLD}${BLUE}"
  echo "╔══════════════════════════════════════╗"
  echo "║    AI Agent Shell - Installer        ║"
  echo "╚══════════════════════════════════════╝"
  echo -e "${NC}"
}

_summary() {
  echo -e "${BOLD}${GREEN}"
  echo "╔══════════════════════════════════════╗"
  echo "║        Installation Complete         ║"
  echo "╚══════════════════════════════════════╝"
  echo -e "${NC}"
}

_usage() {
  echo "Usage: ./install.sh [OPTIONS]"
  echo ""
  echo "  (no flags)      Interactive menu"
  echo "  --all           Run all steps: config + tools + mcp + agents + docker + path"
  echo "  --config        Install Claude Code config files"
  echo "  --tools         Install fnm/node/claude + OS dev tools"
  echo "  --mcp           Install MCP servers"
  echo "  --agents        Install Claude Code agent definitions"
  echo "  --docker        Build Docker images"
  echo "  --path          Set up symlinks, claude wrapper, shell snippets"
  echo "  --skip-docker   Skip Docker build (for use with --all)"
  echo "  -h, --help      Show this help"
}

_run() {
  # Reads do_* vars from caller scope (globals in flag-parse path, locals in _menu).
  # shellcheck source=install/config.sh
  [[ "$do_config" == true ]] && { source "$SCRIPT_DIR/install/config.sh"; install_config; }
  # shellcheck source=install/tools.sh
  [[ "$do_tools"  == true ]] && { source "$SCRIPT_DIR/install/tools.sh";  install_tools;  }
  # shellcheck source=install/mcp.sh
  [[ "$do_mcp"    == true ]] && { source "$SCRIPT_DIR/install/mcp.sh";    install_mcp;    }
  # shellcheck source=install/agents.sh
  [[ "$do_agents" == true ]] && { source "$SCRIPT_DIR/install/agents.sh"; install_agents; }
  # shellcheck source=install/docker.sh
  [[ "$do_docker" == true ]] && { source "$SCRIPT_DIR/install/docker.sh"; install_docker; }
  # shellcheck source=install/path.sh
  [[ "$do_path"   == true ]] && { source "$SCRIPT_DIR/install/path.sh";   install_path;   }
}

_menu() {
  echo "What would you like to install?"
  echo ""
  echo "  1) All (config + tools + MCP + agents + path)"
  echo "  2) Claude Code config (CLAUDE.md, settings, hooks)"
  echo "  3) Tools (fnm, Node.js, Claude Code, dev tools)"
  echo "  4) MCP servers"
  echo "  5) Docker images"
  echo "  6) PATH + shell aliases"
  echo "  7) Claude Code agents"
  echo "  q) Quit"
  echo ""
  read -rp "Select (1-7, q, or multiple e.g. '2 3'): " selection
  echo ""

  local do_config=false do_tools=false do_mcp=false do_docker=false do_path=false do_agents=false
  for token in $selection; do
    case "$token" in
      1) do_config=true; do_tools=true; do_mcp=true; do_agents=true; do_docker=true; do_path=true ;;
      2) do_config=true ;;
      3) do_tools=true ;;
      4) do_mcp=true ;;
      5) do_docker=true ;;
      6) do_path=true ;;
      7) do_agents=true ;;
      q) echo "Quit."; exit 0 ;;
      *) warn "Unknown option: $token" ;;
    esac
  done
  _run
}

# ── main ─────────────────────────────────────────────────────────────────────

_banner

if [[ $# -eq 0 ]]; then
  _menu
  _summary
  exit 0
fi

do_config=false; do_tools=false; do_mcp=false; do_docker=false; do_path=false
do_agents=false; skip_docker=false; do_all=false

for arg in "$@"; do
  case "$arg" in
    --all)         do_all=true ;;
    --config)      do_config=true ;;
    --tools)       do_tools=true ;;
    --mcp)         do_mcp=true ;;
    --docker)      do_docker=true ;;
    --path)        do_path=true ;;
    --agents)      do_agents=true ;;
    --skip-docker) skip_docker=true ;;
    -h|--help)     _usage; exit 0 ;;
    *) err "Unknown flag: $arg"; _usage; exit 1 ;;
  esac
done

if [[ "$do_all" == true ]]; then
  do_config=true; do_tools=true; do_mcp=true; do_agents=true; do_path=true
  [[ "$skip_docker" == false ]] && do_docker=true
fi

_run
_summary
