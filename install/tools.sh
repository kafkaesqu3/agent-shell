#!/usr/bin/env bash
# install_tools: install fnm, Node.js, Claude Code, and OS-specific dev tools
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
  brew install ripgrep fd shellcheck shfmt jq actionlint fzf tmux zsh
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
    fzf tmux zsh \
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
    fzf tmux zsh \
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
  sudo pacman -S --noconfirm --needed \
    ripgrep fd shellcheck shfmt jq \
    fzf tmux zsh \
    python python-pip rust base-devel
  if ! cmd_exists uv; then curl -LsSf https://astral.sh/uv/install.sh | sh; fi
  _install_cargo_tools
  _install_python_tools
  ok "Arch dependencies installed"
}

_install_claude_plugins() {
  if ! cmd_exists claude; then warn "Claude Code not found — skipping plugins"; return; fi

  info "Installing Claude Code plugins..."
  claude plugin marketplace add obra/superpowers-marketplace 2>/dev/null \
    && ok "  superpowers-marketplace added" \
    || warn "  superpowers-marketplace (skipped)"
  local plugins=(
    "superpowers@superpowers-marketplace"
    "commit-commands@claude-plugins-official"
    "hookify@claude-plugins-official"
    "context7@claude-plugins-official"
    "frontend-design@claude-plugins-official"
    "claude-code-setup@claude-plugins-official"
    "claude-md-management@claude-plugins-official"
    "security-guidance@claude-plugins-official"
    "code-review@claude-plugins-official"
  )

  for plugin in "${plugins[@]}"; do
    if claude plugin install "$plugin" 2>/dev/null; then
      ok "  $plugin"
    else
      warn "  $plugin (skipped)"
    fi
  done
  ok "Claude Code plugins installed"
}

install_tools() {
  echo -e "${BOLD}--- Installing Tools ---${NC}"

  # fnm + Node.js 22 LTS
  FNM_BIN="${HOME}/.local/share/fnm"
  if ! cmd_exists fnm && [ ! -x "${FNM_BIN}/fnm" ]; then
    info "Installing fnm..."
    curl -fsSL https://fnm.vercel.app/install | bash
    ok "fnm installed"
  else
    ok "fnm already installed"
  fi
  export PATH="${FNM_BIN}:${PATH}"
  # shellcheck disable=SC1090
  eval "$(fnm env 2>/dev/null)" || true

  if ! fnm ls 2>/dev/null | grep -q "v22"; then
    info "Installing Node.js 22 via fnm..."
    fnm install 22
  fi
  fnm default 22
  eval "$(fnm env)"
  ok "Node.js $(node --version)"

  # ast-grep (AST-aware code search, binary: sg)
  if npm install -g @ast-grep/cli 2>/dev/null; then
    ok "ast-grep installed"
  else
    warn "ast-grep skipped"
  fi

  # Claude Code (official installer)
  if cmd_exists claude; then
    ok "Claude Code already installed ($(claude --version 2>/dev/null | head -1))"
  else
    info "Installing Claude Code..."
    curl -fsSL https://claude.ai/install.sh | bash 2>&1 | tail -3
    ok "Claude Code installed"
  fi

  # Claude Code plugins
  _install_claude_plugins

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
