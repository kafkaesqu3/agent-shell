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
    if grep -q "ai-agent" "$real_claude" 2>/dev/null; then
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
# fnm (Node.js version manager)
export PATH="$HOME/.local/share/fnm:$PATH"
eval "$(fnm env 2>/dev/null)" || true

# claude is an alias for ai-agent — all routing (host/Docker, profiles, --yolo)
# is handled there.
alias claude='ai-agent'
SHELLFUNC

  echo ""
  echo -e "${BOLD}2. ${BLUE}PowerShell profile${NC} (Documents/PowerShell/Microsoft.PowerShell_profile.ps1)"
  echo -e "   ${YELLOW}For Windows users calling claude from PowerShell via WSL:${NC}"
  echo ""
  cat << 'PSFUNC'
# claude and ai-agent are interchangeable entry points — all routing
# (host/Docker, profiles, --yolo) is handled by ai-agent in WSL.
function claude   { wsl ai-agent @args }
function ai-agent { wsl ai-agent @args }
PSFUNC

  echo ""
  echo -e "  ${YELLOW}Tip:${NC} 'claude' and 'ai-agent' are interchangeable — both route through ai-agent."
  echo -e "        Default: Docker (isolated, reproducible)."
  echo -e "        'claude --host' / 'ai-agent --host': run directly on this machine."
  echo -e "        'claude --work' / '--local [MODEL]': layer a credential profile on top."
  echo -e "        '--yolo': enable --dangerously-skip-permissions (works with all modes)."
  echo ""
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/install/common.sh"
  install_path
fi
