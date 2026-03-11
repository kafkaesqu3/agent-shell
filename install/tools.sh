#!/usr/bin/env bash
# install_tools: install nvm, Node.js, Claude Code, and OS-specific dev tools
set -euo pipefail
# shellcheck source=install/common.sh
[[ -z "${SCRIPT_DIR:-}" ]] && source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/install/common.sh"

_install_cargo_tools() {
  if ! cmd_exists cargo; then warn "Skipping cargo tools (cargo not found)"; return; fi
  [[ -d "$HOME/.cargo/bin" ]] && export PATH="$HOME/.cargo/bin:$PATH"
  info "Installing Rust tools..."
  cargo install git-wt      --quiet 2>/dev/null || warn "git-wt skipped"
  cargo install cargo-audit --quiet 2>/dev/null || warn "cargo-audit skipped"
  cargo install cargo-deny  --quiet 2>/dev/null || warn "cargo-deny skipped"
  ok "Rust tools installed"
}

_install_python_tools() {
  info "Installing Python tools..."
  if cmd_exists uv; then
    uv pip install --upgrade ruff pytest pip-audit 2>/dev/null || warn "Python tools via uv skipped"
  elif cmd_exists pip3; then
    pip3 install --upgrade ruff pytest pip-audit 2>/dev/null || warn "Python tools via pip3 skipped"
  fi
  ok "Python tools installed"
}

_install_macos() {
  info "Installing macOS dependencies..."
  if ! cmd_exists brew; then
    info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  brew install ripgrep fd-find shellcheck shfmt jq actionlint
  if ! cmd_exists node; then brew install node@22; fi
  if ! cmd_exists cargo; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  fi
  if ! cmd_exists python3; then brew install python@3; fi
  _install_cargo_tools
  _install_python_tools
  ok "macOS dependencies installed"
}

_install_ubuntu() {
  info "Installing Ubuntu/Debian dependencies..."
  sudo apt-get update -qq
  sudo apt-get install -y \
    curl git build-essential \
    ripgrep fd-find shellcheck shfmt jq \
    python3-full python3-pip
  if ! cmd_exists cargo; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  fi
  if ! cmd_exists uv; then curl -LsSf https://astral.sh/uv/install.sh | sh; fi
  _install_cargo_tools
  _install_python_tools
  ok "Ubuntu/Debian dependencies installed"
}

_install_fedora() {
  info "Installing Fedora/RHEL dependencies..."
  sudo dnf groupinstall -y "Development Tools"
  sudo dnf install -y ripgrep fd shellcheck shfmt jq \
    python3 python3-devel openssl-devel
  if ! cmd_exists cargo; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  fi
  if ! cmd_exists uv; then curl -LsSf https://astral.sh/uv/install.sh | sh; fi
  _install_cargo_tools
  _install_python_tools
  ok "Fedora/RHEL dependencies installed"
}

_install_arch() {
  info "Installing Arch dependencies..."
  sudo pacman -Syu
  sudo pacman -S --noconfirm \
    ripgrep fd shellcheck shfmt jq \
    python python-pip rust base-devel
  if ! cmd_exists uv; then curl -LsSf https://astral.sh/uv/install.sh | sh; fi
  _install_cargo_tools
  _install_python_tools
  ok "Arch dependencies installed"
}

install_tools() {
  echo -e "${BOLD}--- Installing Tools ---${NC}"

  # nvm + Node.js
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

  # Claude Code (official installer)
  info "Installing Claude Code..."
  curl -fsSL https://claude.ai/install.sh | bash 2>&1 | tail -3
  ok "Claude Code installed"

  # OS-specific dev tools
  local os
  os=$(detect_os)
  case "$os" in
    macos)  _install_macos  ;;
    ubuntu) _install_ubuntu ;;
    fedora) _install_fedora ;;
    arch)   _install_arch   ;;
    *)      warn "Unsupported OS '$os' — skipping dev tools" ;;
  esac

  echo ""
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/install/common.sh"
  install_tools
fi
