#!/usr/bin/env bash
# install_docker: build ai-agent Docker images
set -euo pipefail
# shellcheck source=install/common.sh
[[ -z "${SCRIPT_DIR:-}" ]] && source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/install/common.sh"

install_docker() {
  echo -e "${BOLD}--- Building Docker Images ---${NC}"

  if ! cmd_exists docker; then
    err "Docker not found. Install Docker then re-run with --docker."
    return 1
  fi
  if ! docker info &>/dev/null 2>&1; then
    err "Docker daemon not running."
    return 1
  fi

  echo "Select which image(s) to build:"
  echo "  1) lite     — Claude Code only (fast build)"
  echo "  2) base     — Full dev environment (Go, MCP servers, AI tools) [default]"
  echo "  3) browsing — Full environment + Chromium (~2x larger)"
  echo "  4) all      — All three"
  echo ""
  if [[ -t 0 ]]; then
    read -rp "Choice [1/2/3/4, default=2]: " -n 1 choice
    echo ""
  else
    choice=""
    info "Non-interactive shell — defaulting to base image"
  fi
  choice="${choice:-2}"

  case "$choice" in
    1)
      info "Building ai-agent:lite..."
      docker build -t ai-agent:lite --target lite "$SCRIPT_DIR"
      ok "ai-agent:lite built"
      ;;
    3)
      info "Building ai-agent:browsing (includes full base)..."
      docker build -t ai-agent:browsing --target browsing "$SCRIPT_DIR"
      ok "ai-agent:browsing built"
      ;;
    4)
      info "Building ai-agent:lite..."
      docker build -t ai-agent:lite --target lite "$SCRIPT_DIR"
      ok "ai-agent:lite built"

      info "Building ai-agent:latest (base)..."
      docker build -t ai-agent:latest --target base "$SCRIPT_DIR"
      ok "ai-agent:latest built"

      info "Building ai-agent:browsing..."
      docker build -t ai-agent:browsing --target browsing "$SCRIPT_DIR"
      ok "ai-agent:browsing built"
      ;;
    *)
      info "Building ai-agent:latest (base)..."
      docker build -t ai-agent:latest --target base "$SCRIPT_DIR"
      ok "ai-agent:latest built"
      ;;
  esac

  echo ""
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/install/common.sh"
  install_docker
fi
