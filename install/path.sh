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

  # Helper: append a block to the profile only if a marker string isn't already present
  _append_once() {
    local marker="$1" block="$2"
    if ! grep -qF "$marker" "$profile" 2>/dev/null; then
      printf '\n%s\n' "$block" >> "$profile"
      ok "  Written to $profile: $marker"
    else
      ok "  Already in $profile: $marker"
    fi
  }

  echo -e "${BOLD}--- Writing shell config to $profile ---${NC}"

  _append_once '.local/bin' \
'# AI Agent Shell — added by install.sh
export PATH="$HOME/.local/bin:$PATH"'

  _append_once 'local/share/fnm' \
'# fnm (Node.js version manager)
export PATH="$HOME/.local/share/fnm:$PATH"
eval "$(fnm env 2>/dev/null)" || true'

  _append_once "alias claude='ai-agent'" \
"# claude routes through ai-agent (host/Docker, profiles, --yolo)
alias claude='ai-agent'"

  ok "Run: source $profile"

  # .env template
  if [ ! -f "$CONFIG_DIR/.env" ]; then
    cp "$SCRIPT_DIR/.env.example" "$CONFIG_DIR/.env"
    info "Copied .env template → $CONFIG_DIR/.env (edit with your API keys)"
  fi

  echo ""
  echo -e "${BOLD}Windows/PowerShell users:${NC} add to Documents/PowerShell/Microsoft.PowerShell_profile.ps1"
  echo ""
  cat << 'PSFUNC'
function claude   { wsl ai-agent @args }
function ai-agent { wsl ai-agent @args }
PSFUNC
  echo ""
  echo -e "  ${YELLOW}Tip:${NC} 'claude --host' runs locally · '--work/--local' layers credentials · '--yolo' skips permissions"
  echo ""
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/install/common.sh"
  install_path
fi
