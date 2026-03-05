#!/usr/bin/env bash
set -euo pipefail

# Installs CLI tools, language runtimes, and development tools

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly QUIET="${QUIET:-}"

# Detect OS
detect_os() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "macos"
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if command -v apt-get &>/dev/null; then
      echo "ubuntu"
    elif command -v yum &>/dev/null; then
      echo "fedora"
    elif command -v pacman &>/dev/null; then
      echo "arch"
    else
      echo "linux"
    fi
  else
    echo "unknown"
  fi
}

log() {
  if [[ -z "$QUIET" ]]; then
    echo "[install] $*" >&2
  fi
}

log_done() {
  if [[ -z "$QUIET" ]]; then
    echo "[✓] $*" >&2
  fi
}

# Check if command exists
cmd_exists() {
  command -v "$1" &>/dev/null
}

# Install macOS dependencies
install_macos() {
  log "Installing macOS dependencies..."
  
  if ! cmd_exists brew; then
    log "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  
  # CLI tools
  brew install ripgrep fd-find shellcheck shfmt jq
  brew install ast-grep axel  # axel includes actionlint
  brew install actionlint
  
  # Node (via nvm is preferred, but brew works)
  if ! cmd_exists node; then
    brew install node@22
  fi
  
  # Rust
  if ! cmd_exists cargo; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  fi
  
  # Python
  if ! cmd_exists python3.13; then
    brew install python@3.13
  fi
  
  # Additional tools via cargo/npm/pip
  install_cargo_tools
  install_npm_tools
  install_python_tools
  
  log_done "macOS dependencies installed"
}

# Install Ubuntu/Debian dependencies
install_ubuntu() {
  log "Installing Ubuntu/Debian dependencies..."
  
  sudo apt-get update -qq
  sudo apt-get install -y \
    curl git build-essential \
    ripgrep fd-find shellcheck shfmt jq \
    python3-full python3-pip \
    npm nodejs
  
  # Install rustup for Rust
  if ! cmd_exists cargo; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  fi
  
  # Install uv for Python
  if ! cmd_exists uv; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
  fi
  
  # AST-grep
  if ! cmd_exists ast-grep; then
    npm install -g ast-grep 2>/dev/null || log "Failed to install ast-grep via npm"
  fi
  
  # Additional tools
  install_cargo_tools
  install_npm_tools
  install_python_tools
  
  log_done "Ubuntu/Debian dependencies installed"
}

# Install Fedora/RHEL dependencies
install_fedora() {
  log "Installing Fedora/RHEL dependencies..."
  
  sudo dnf groupinstall -y "Development Tools"
  sudo dnf install -y \
    ripgrep fd shellcheck shfmt jq \
    nodejs npm python3 python3-devel \
    openssl-devel
  
  # Rust
  if ! cmd_exists cargo; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  fi
  
  # Python tooling
  if ! cmd_exists uv; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
  fi
  
  # Additional tools
  install_cargo_tools
  install_npm_tools
  install_python_tools
  
  log_done "Fedora/RHEL dependencies installed"
}

# Install Arch dependencies
install_arch() {
  log "Installing Arch dependencies..."
  
  sudo pacman -Syu
  sudo pacman -S --noconfirm \
    ripgrep fd shellcheck shfmt jq \
    nodejs npm python python-pip \
    rust base-devel
  
  # Python tooling
  if ! cmd_exists uv; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
  fi
  
  # Additional tools
  install_cargo_tools
  install_npm_tools
  install_python_tools
  
  log_done "Arch dependencies installed"
}

# Install tools via cargo
install_cargo_tools() {
  if ! cmd_exists cargo; then
    log "Skipping cargo-based tools (cargo not found)"
    return
  fi
  
  log "Installing Rust tools..."
  
  # Add to PATH if needed
  if [[ -d "$HOME/.cargo/bin" ]]; then
    export PATH="$HOME/.cargo/bin:$PATH"
  fi
  
  # wt (git worktree manager)
  cargo install git-wt --quiet 2>/dev/null || log "wt installation skipped"
  
  # cargo-audit (supply chain security)
  cargo install cargo-audit --quiet 2>/dev/null || log "cargo-audit installation skipped"
  
  # cargo-deny
  cargo install cargo-deny --quiet 2>/dev/null || log "cargo-deny installation skipped"
  
  # cargo-careful (for testing)
  cargo install cargo-careful --quiet 2>/dev/null || log "cargo-careful installation skipped"
  
  log_done "Rust tools installed"
}

# Install tools via npm
install_npm_tools() {
  if ! cmd_exists npm; then
    log "Skipping npm-based tools (npm not found)"
    return
  fi
  
  log "Installing Node.js tools..."
  
  # prek (fast git hooks)
  npm install -g prek 2>/dev/null || log "prek installation skipped"
  
  # zizmor (Actions security audit)
  npm install -g zizmor 2>/dev/null || log "zizmor installation skipped"
  
  # oxlint and oxfmt
  npm install -g oxlint oxfmt 2>/dev/null || log "oxlint/oxfmt installation skipped"
  
  log_done "Node.js tools installed"
}

# Install tools via pip/uv
install_python_tools() {
  log "Installing Python tools..."
  
  if cmd_exists uv; then
    # Use uv for faster installation
    uv pip install --upgrade \
      ruff \
      pytest \
      pip-audit \
      2>/dev/null || log "Python tools via uv installation skipped"
    
    # Install ty (type checker) via uv
    uv pip install --upgrade ty 2>/dev/null || log "ty installation skipped"
  elif cmd_exists pip3; then
    # Fallback to pip3
    pip3 install --upgrade \
      ruff \
      pytest \
      pip-audit \
      2>/dev/null || log "Python tools via pip3 installation skipped"
  fi
  
  log_done "Python tools installed"
}

# Install trash command (safe rm alternative)
install_trash() {
  local os=$1
  log "Installing trash (safe rm alternative)..."
  
  case "$os" in
    macos)
      brew install trash 2>/dev/null || log "trash installation skipped"
      ;;
    ubuntu)
      sudo apt-get install -y trash-cli 2>/dev/null || log "trash installation skipped"
      ;;
    fedora)
      sudo dnf install -y trash-cli 2>/dev/null || log "trash installation skipped"
      ;;
    arch)
      sudo pacman -S --noconfirm trash-cli 2>/dev/null || log "trash installation skipped"
      ;;
  esac
}

# Main installation flow
main() {
  log "Trail of Bits Claude Code Config Setup"
  log "======================================="
  
  local os
  os=$(detect_os)
  log "Detected OS: $os"
  
  case "$os" in
    macos)
      install_macos
      ;;
    ubuntu)
      install_ubuntu
      ;;
    fedora)
      install_fedora
      ;;
    arch)
      install_arch
      ;;
    *)
      log "Unsupported OS: $os"
      log "Please install dependencies manually from: $SCRIPT_DIR/README.md"
      exit 1
      ;;
  esac
  
  # Install trash as a fallback
  install_trash "$os"
  
  # Final setup
  log ""
  log "======================================="
  log_done "Installation complete!"
  log ""
  log "Next steps:"
  log "1. Review settings.json for your environment"
  log "2. Set up MCP servers: $SCRIPT_DIR/mcp-template.json"
  log "3. Install hooks: cd to your repo and run 'prek install'"
  log "4. Review development standards: $SCRIPT_DIR/claude-md-template.md"
}

main "$@"
