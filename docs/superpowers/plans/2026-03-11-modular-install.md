# Modular Install Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor `install.sh` into a modular dispatcher backed by focused sub-scripts, merging `claude-config/setup.sh` and adding a dedicated `install/mcp.sh`.

**Architecture:** `install.sh` becomes a ~70-line dispatcher that sources `install/common.sh` then sources and calls module functions in order. Each module in `install/` has one public function, is independently runnable, and passes shellcheck. The interactive menu and flag parser both dispatch to the same module functions.

**Spec:** `docs/superpowers/specs/2026-03-11-modular-install-design.md`

**Tech Stack:** bash, shellcheck (validation), jq (settings merge)

---

## Chunk 1: Create modules

### Task 1: Create install/common.sh

**Files:**
- Create: `install/common.sh`

- [ ] **Step 1: Create the file**

```bash
#!/usr/bin/env bash
# Shared constants and helpers — sourced by install.sh and all install/* modules.
# Not independently runnable.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/ai-agent}"
LOCAL_BIN="${LOCAL_BIN:-$HOME/.local/bin}"

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

cmd_exists() { command -v "$1" &>/dev/null; }

detect_os() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "macos"
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if cmd_exists apt-get;                    then echo "ubuntu"
    elif cmd_exists dnf || cmd_exists yum;    then echo "fedora"
    elif cmd_exists pacman;                   then echo "arch"
    else                                           echo "linux"
    fi
  else
    echo "unknown"
  fi
}
```

- [ ] **Step 2: Validate with shellcheck**

```bash
shellcheck install/common.sh
```

Expected: no output (clean)

- [ ] **Step 3: Commit**

```bash
git add install/common.sh
git commit -m "feat: add install/common.sh with shared helpers and detect_os"
```

---

### Task 2: Create install/config.sh

**Files:**
- Create: `install/config.sh`
- Source material: `install.sh` lines 68–154 (§1 Claude Code Configuration)

- [ ] **Step 1: Create the file**

Extract §1 from `install.sh` into an `install_config()` function. The logic is identical — only the variable names change to locals and the section header moves inside the function.

```bash
#!/usr/bin/env bash
# install_config: copy Claude Code config files to ~/.claude
set -euo pipefail
# shellcheck source=install/common.sh
[[ -z "${SCRIPT_DIR:-}" ]] && source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/install/common.sh"

install_config() {
  echo -e "${BOLD}--- Claude Code Configuration ---${NC}"
  mkdir -p "$CLAUDE_HOME"

  # --- settings.json: merge MCP servers ---
  local repo_settings="$SCRIPT_DIR/claude-config/settings.json"
  local host_settings="$CLAUDE_HOME/settings.json"

  if [ -f "$host_settings" ]; then
    info "Merging repo settings into existing $host_settings"
    jq -s '
      .[1] * {
        mcpServers: (.[1].mcpServers * (.[0].mcpServers // {})),
        model:                 (.[0].model // .[1].model),
        enabledPlugins:        (.[0].enabledPlugins // {}),
        clearTerminalOnLaunch: (.[0].clearTerminalOnLaunch // .[1].clearTerminalOnLaunch),
        attribution:           (.[0].attribution // .[1].attribution)
      }
      | if .model == null then del(.model) else . end
    ' "$host_settings" "$repo_settings" > /tmp/claude-settings-merged.json

    local merged=/tmp/claude-settings-merged.json
    [ -n "${BRIGHTDATA_API_KEY:-}" ] && \
      sed -i "s|__BRIGHTDATA_API_KEY__|${BRIGHTDATA_API_KEY}|g" "$merged"

    cp "$host_settings" "${host_settings}.bak"
    mv "$merged" "$host_settings"
    ok "Settings merged (backup at settings.json.bak)"
  else
    info "No existing settings.json — copying from repo"
    cp "$repo_settings" "$host_settings"
    [ -n "${BRIGHTDATA_API_KEY:-}" ] && \
      sed -i "s|__BRIGHTDATA_API_KEY__|${BRIGHTDATA_API_KEY}|g" "$host_settings"
    ok "settings.json installed"
  fi

  # --- CLAUDE.md ---
  local repo_claude_md="$SCRIPT_DIR/claude-config/CLAUDE.md"
  local host_claude_md="$CLAUDE_HOME/CLAUDE.md"
  local marker="# Global Development Standards"

  if [ -f "$host_claude_md" ]; then
    if grep -qF "$marker" "$host_claude_md" 2>/dev/null; then
      ok "CLAUDE.md already contains repo instructions"
    else
      info "Replacing CLAUDE.md with repo version (backup at CLAUDE.md.bak)"
      cp "$host_claude_md" "${host_claude_md}.bak"
      cp "$repo_claude_md" "$host_claude_md"
      ok "CLAUDE.md replaced"
    fi
  else
    cp "$repo_claude_md" "$host_claude_md"
    ok "CLAUDE.md installed"
  fi

  # --- statusline.sh ---
  if [ -f "$SCRIPT_DIR/claude-config/statusline.sh" ]; then
    cp "$SCRIPT_DIR/claude-config/statusline.sh" "$CLAUDE_HOME/statusline.sh"
    chmod +x "$CLAUDE_HOME/statusline.sh"
    ok "statusline.sh installed"
  else
    warn "statusline.sh not found in repo — skipping"
  fi

  # --- skill-profiles.json ---
  if [ -f "$SCRIPT_DIR/claude-config/skill-profiles.json" ]; then
    cp "$SCRIPT_DIR/claude-config/skill-profiles.json" "$CLAUDE_HOME/skill-profiles.json"
    ok "skill-profiles.json installed"
  fi

  # --- hooks ---
  if [ -d "$SCRIPT_DIR/claude-config/hooks" ]; then
    mkdir -p "$CLAUDE_HOME/hooks"
    cp "$SCRIPT_DIR/claude-config/hooks"/*.sh "$CLAUDE_HOME/hooks/"
    chmod +x "$CLAUDE_HOME/hooks/"*.sh
    ok "hook scripts installed"
  else
    warn "hooks/ directory not found in repo — skipping"
  fi

  echo ""
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/install/common.sh"
  install_config
fi
```

- [ ] **Step 2: Validate with shellcheck**

```bash
shellcheck install/config.sh
```

Expected: no output

- [ ] **Step 3: Commit**

```bash
git add install/config.sh
git commit -m "feat: add install/config.sh — Claude Code config installer module"
```

---

### Task 3: Create install/mcp.sh

**Files:**
- Create: `install/mcp.sh`
- Source material: MCP-specific lines from `install.sh` §2 (lines 191–213)

- [ ] **Step 1: Create the file**

```bash
#!/usr/bin/env bash
# install_mcp: install MCP servers (npm globals + mcp-server-fetch venv)
set -euo pipefail
# shellcheck source=install/common.sh
[[ -z "${SCRIPT_DIR:-}" ]] && source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/install/common.sh"

install_mcp() {
  echo -e "${BOLD}--- Installing MCP Servers ---${NC}"

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

  # mcp-server-fetch — isolated venv avoids Ubuntu 24.04 system pip conflict
  if cmd_exists python3; then
    local fetch_venv="$HOME/.local/share/mcp-fetch-venv"
    info "Installing mcp-server-fetch in venv at $fetch_venv..."
    python3 -m venv "$fetch_venv"
    "$fetch_venv/bin/pip" install --quiet mcp-server-fetch
    mkdir -p "$LOCAL_BIN"
    ln -sf "$fetch_venv/bin/mcp-server-fetch" "$LOCAL_BIN/mcp-server-fetch"
    ok "mcp-server-fetch → $LOCAL_BIN/mcp-server-fetch"
  else
    warn "python3 not found — skipping mcp-server-fetch"
  fi

  echo ""
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/install/common.sh"
  install_mcp
fi
```

- [ ] **Step 2: Validate with shellcheck**

```bash
shellcheck install/mcp.sh
```

Expected: no output

- [ ] **Step 3: Commit**

```bash
git add install/mcp.sh
git commit -m "feat: add install/mcp.sh — dedicated MCP server installer module"
```

---

### Task 4: Create install/tools.sh

**Files:**
- Create: `install/tools.sh`
- Source material: `install.sh` §2 lines 162–188 (nvm/node/claude) + `claude-config/setup.sh` (OS functions, cargo tools, python tools)

- [ ] **Step 1: Create the file**

Merge nvm/node/claude from `install.sh` with the OS-aware installer functions from `claude-config/setup.sh`. Private helpers are prefixed with `_` to signal they are internal.

```bash
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
```

- [ ] **Step 2: Validate with shellcheck**

```bash
shellcheck install/tools.sh
```

Expected: no output

- [ ] **Step 3: Commit**

```bash
git add install/tools.sh
git commit -m "feat: add install/tools.sh — nvm/node/claude + OS dev tools (merges setup.sh)"
```

---

### Task 5: Create install/docker.sh

**Files:**
- Create: `install/docker.sh`
- Source material: `install.sh` §3 lines 221–247

- [ ] **Step 1: Create the file**

```bash
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
```

- [ ] **Step 2: Validate with shellcheck**

```bash
shellcheck install/docker.sh
```

Expected: no output

- [ ] **Step 3: Commit**

```bash
git add install/docker.sh
git commit -m "feat: add install/docker.sh — Docker image builder module"
```

---

### Task 6: Create install/path.sh

**Files:**
- Create: `install/path.sh`
- Source material: `install.sh` §4 lines 252–369

- [ ] **Step 1: Create the file**

```bash
#!/usr/bin/env bash
# install_path: set up PATH, symlinks, claude wrapper, and shell config snippets
set -euo pipefail
# shellcheck source=install/common.sh
[[ -z "${SCRIPT_DIR:-}" ]] && source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/install/common.sh"

install_path() {
  echo -e "${BOLD}--- PATH Setup ---${NC}"

  mkdir -p "$CONFIG_DIR" "$LOCAL_BIN"

  local shell_name
  shell_name=$(basename "${SHELL:-bash}")
  local profile
  case "$shell_name" in
    zsh)  profile="$HOME/.zshrc" ;;
    bash) profile="$HOME/.bashrc" ;;
    *)    profile="$HOME/.profile" ;;
  esac

  # ai-agent symlink
  chmod +x "$SCRIPT_DIR/ai-agent.sh"
  ln -sf "$SCRIPT_DIR/ai-agent.sh" "$LOCAL_BIN/ai-agent"
  ok "Symlinked ai-agent → $LOCAL_BIN/ai-agent"

  # claude wrapper: route to container by default, --host for local
  chmod +x "$SCRIPT_DIR/claude-wrapper.sh"
  local real_claude
  real_claude="$(command -v claude 2>/dev/null || true)"
  if [ -z "$real_claude" ]; then
    for _try in "$HOME/.claude/local/claude" "$HOME/.local/bin/claude" "/usr/local/bin/claude"; do
      if [ -x "$_try" ]; then real_claude="$_try"; break; fi
    done
  fi

  if [ -n "$real_claude" ]; then
    if grep -q "claude-host" "$real_claude" 2>/dev/null; then
      cp "$SCRIPT_DIR/claude-wrapper.sh" "$real_claude"
      ok "claude wrapper updated"
    else
      local claude_dir
      claude_dir="$(dirname "$real_claude")"
      cp "$real_claude" "$claude_dir/claude-host"
      chmod +x "$claude_dir/claude-host"
      cp "$SCRIPT_DIR/claude-wrapper.sh" "$real_claude"
      chmod +x "$real_claude"
      ok "claude wrapper installed (original binary → claude-host)"
    fi
  else
    cp "$SCRIPT_DIR/claude-wrapper.sh" "$LOCAL_BIN/claude"
    chmod +x "$LOCAL_BIN/claude"
    warn "claude not found — wrapper installed at $LOCAL_BIN/claude (install claude first, re-run)"
  fi

  # PATH export
  if ! echo "$PATH" | grep -q "$LOCAL_BIN"; then
    { echo ""; echo "# AI Agent Shell — added by install.sh"
      echo "export PATH=\"\$HOME/.local/bin:\$PATH\""; } >> "$profile"
    ok "PATH updated in $profile (run: source $profile)"
  else
    ok "$LOCAL_BIN already in PATH"
  fi

  # .env template
  if [ ! -f "$CONFIG_DIR/.env" ]; then
    cp "$SCRIPT_DIR/.env.example" "$CONFIG_DIR/.env"
    info "Copied .env template → $CONFIG_DIR/.env (edit with your API keys)"
  fi

  # Shell snippets
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
#         use --yolo to enable --dangerously-skip-permissions
claude() {
  local -a _args=()
  for _arg in "$@"; do
    [[ "$_arg" == "--yolo" ]] && _args+=("--dangerously-skip-permissions") || _args+=("$_arg")
  done
  if [[ "${_args[0]:-}" == "--host" ]]; then
    command claude-host "${_args[@]:1}"
  else
    ai-agent claude "${_args[@]+"${_args[@]}"}"
  fi
}
SHELLFUNC

  echo ""
  echo -e "${BOLD}2. ${BLUE}PowerShell profile${NC} (Documents/PowerShell/Microsoft.PowerShell_profile.ps1)"
  echo -e "   ${YELLOW}For Windows users calling claude from PowerShell via WSL:${NC}"
  echo ""
  cat << 'PSFUNC'
# claude: runs in Docker by default; use --host to run directly on WSL
#         use --yolo to enable --dangerously-skip-permissions
function claude {
  $mapped = @($args | ForEach-Object {
    if ($_ -eq '--yolo') { '--dangerously-skip-permissions' } else { $_ }
  })
  if ($mapped.Count -gt 0 -and $mapped[0] -eq "--host") {
    $rest = if ($mapped.Count -gt 1) { $mapped[1..($mapped.Count - 1)] } else { @() }
    wsl claude --host @rest
  } else {
    wsl ai-agent claude @mapped
  }
}
PSFUNC

  echo ""
  echo -e "  ${YELLOW}Tip:${NC} 'claude' launches in Docker (isolated, reproducible)."
  echo -e "        'claude --host' runs the local binary directly on this machine."
  echo -e "        'claude --yolo' enables --dangerously-skip-permissions (works with both)."
  echo ""
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/install/common.sh"
  install_path
fi
```

- [ ] **Step 2: Validate with shellcheck**

```bash
shellcheck install/path.sh
```

Expected: no output

- [ ] **Step 3: Commit**

```bash
git add install/path.sh
git commit -m "feat: add install/path.sh — PATH, symlinks, and shell alias module"
```

---

## Chunk 2: Dispatcher + cleanup

### Task 7: Rewrite install.sh as dispatcher

**Files:**
- Modify: `install.sh` (full rewrite)

- [ ] **Step 1: Replace install.sh contents**

```bash
#!/usr/bin/env bash
# AI Agent Shell — Install Script
# Primary entrypoint for configuring the environment.
#
# Usage: ./install.sh [OPTIONS]
#   (no flags)      Interactive menu
#   --all           Run all steps: config + tools + mcp + docker + path
#   --config        Install Claude Code config files
#   --tools         Install nvm/node/claude + OS dev tools
#   --mcp           Install MCP servers
#   --docker        Build Docker images
#   --path          Set up symlinks, claude wrapper, shell snippets
#   --skip-docker   Skip Docker build when used with --all
#   -h, --help      Show help
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=install/common.sh
source "$SCRIPT_DIR/install/common.sh"

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
  echo "  --all           Run all steps: config + tools + mcp + docker + path"
  echo "  --config        Install Claude Code config files"
  echo "  --tools         Install nvm/node/claude + OS dev tools"
  echo "  --mcp           Install MCP servers"
  echo "  --docker        Build Docker images"
  echo "  --path          Set up symlinks, claude wrapper, shell snippets"
  echo "  --skip-docker   Skip Docker build (for use with --all)"
  echo "  -h, --help      Show this help"
}

_run() {
  local do_config=$1 do_tools=$2 do_mcp=$3 do_docker=$4 do_path=$5
  # shellcheck source=install/config.sh
  [[ "$do_config" == true ]] && { source "$SCRIPT_DIR/install/config.sh"; install_config; }
  # shellcheck source=install/tools.sh
  [[ "$do_tools"  == true ]] && { source "$SCRIPT_DIR/install/tools.sh";  install_tools;  }
  # shellcheck source=install/mcp.sh
  [[ "$do_mcp"    == true ]] && { source "$SCRIPT_DIR/install/mcp.sh";    install_mcp;    }
  # shellcheck source=install/docker.sh
  [[ "$do_docker" == true ]] && { source "$SCRIPT_DIR/install/docker.sh"; install_docker; }
  # shellcheck source=install/path.sh
  [[ "$do_path"   == true ]] && { source "$SCRIPT_DIR/install/path.sh";   install_path;   }
}

_menu() {
  echo "What would you like to install?"
  echo ""
  echo "  1) All (config + tools + MCP + path)"
  echo "  2) Claude Code config (CLAUDE.md, settings, hooks)"
  echo "  3) Tools (nvm, Node.js, Claude Code, dev tools)"
  echo "  4) MCP servers"
  echo "  5) Docker images"
  echo "  6) PATH + shell aliases"
  echo "  q) Quit"
  echo ""
  read -rp "Select (1-6, q, or multiple e.g. '2 3'): " selection
  echo ""

  local do_config=false do_tools=false do_mcp=false do_docker=false do_path=false
  for token in $selection; do
    case "$token" in
      1) do_config=true; do_tools=true; do_mcp=true; do_path=true ;;
      2) do_config=true ;;
      3) do_tools=true ;;
      4) do_mcp=true ;;
      5) do_docker=true ;;
      6) do_path=true ;;
      q) echo "Quit."; exit 0 ;;
      *) warn "Unknown option: $token" ;;
    esac
  done
  _run "$do_config" "$do_tools" "$do_mcp" "$do_docker" "$do_path"
}

# ── main ─────────────────────────────────────────────────────────────────────

_banner

if [[ $# -eq 0 ]]; then
  _menu
  _summary
  exit 0
fi

do_config=false; do_tools=false; do_mcp=false; do_docker=false; do_path=false
skip_docker=false; do_all=false

for arg in "$@"; do
  case "$arg" in
    --all)         do_all=true ;;
    --config)      do_config=true ;;
    --tools)       do_tools=true ;;
    --mcp)         do_mcp=true ;;
    --docker)      do_docker=true ;;
    --path)        do_path=true ;;
    --skip-docker) skip_docker=true ;;
    -h|--help)     _usage; exit 0 ;;
    *) err "Unknown flag: $arg"; _usage; exit 1 ;;
  esac
done

if [[ "$do_all" == true ]]; then
  do_config=true; do_tools=true; do_mcp=true; do_path=true
  [[ "$skip_docker" == false ]] && do_docker=true
fi

_run "$do_config" "$do_tools" "$do_mcp" "$do_docker" "$do_path"
_summary
```

- [ ] **Step 2: Validate with shellcheck**

```bash
shellcheck install.sh
```

Expected: no output

- [ ] **Step 3: Verify help output looks right**

```bash
bash install.sh --help
```

Expected: usage block printed cleanly, exits 0

- [ ] **Step 4: Commit**

```bash
git add install.sh
git commit -m "refactor: rewrite install.sh as modular dispatcher with interactive menu"
```

---

### Task 8: Delete setup.sh and verify

**Files:**
- Delete: `claude-config/setup.sh`

- [ ] **Step 1: Confirm setup.sh is fully superseded**

Verify all functions from `claude-config/setup.sh` are present in `install/tools.sh`:
- `detect_os` → `install/common.sh` ✓
- `install_macos/ubuntu/fedora/arch` → `install/tools.sh` as `_install_*` ✓
- `install_cargo_tools` → `install/tools.sh` as `_install_cargo_tools` ✓
- `install_python_tools` → `install/tools.sh` as `_install_python_tools` ✓

- [ ] **Step 2: Check nothing references setup.sh**

```bash
grep -r "setup.sh" . --include="*.sh" --include="*.md" -l
```

Expected: only `CLAUDE.md` or docs (update any references found before deleting)

- [ ] **Step 3: Delete setup.sh**

```bash
git rm claude-config/setup.sh
```

- [ ] **Step 4: Run shellcheck on all install scripts**

```bash
shellcheck install.sh install/common.sh install/config.sh install/tools.sh \
           install/mcp.sh install/docker.sh install/path.sh
```

Expected: clean

- [ ] **Step 5: Smoke-test module standalone execution (dry run)**

```bash
# Verify each module can be sourced without errors
bash -c 'source install/common.sh && echo "common OK"'
bash -c 'source install/common.sh && source install/config.sh && echo "config OK"'
bash -c 'source install/common.sh && source install/mcp.sh && echo "mcp OK"'
bash -c 'source install/common.sh && source install/docker.sh && echo "docker OK"'
bash -c 'source install/common.sh && source install/path.sh && echo "path OK"'
```

Expected: each line prints `<name> OK`

- [ ] **Step 6: Final commit**

```bash
git add -A
git commit -m "feat: complete modular install refactor — delete claude-config/setup.sh"
```
