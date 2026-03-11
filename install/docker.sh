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
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/install/common.sh"
  install_docker
fi
