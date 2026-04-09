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

  # claude wrapper: install into a dedicated bin dir that precedes ~/.local/bin in PATH.
  # This survives Claude self-updates, which only touch ~/.local/bin/claude (via symlink).
  local agent_bin="$HOME/.local/share/ai-agent/bin"
  mkdir -p "$agent_bin"
  chmod +x "$SCRIPT_DIR/claude-wrapper.sh"
  cp "$SCRIPT_DIR/claude-wrapper.sh" "$agent_bin/claude"
  chmod +x "$agent_bin/claude"
  ok "claude wrapper installed at $agent_bin/claude"

  # Back up the real claude binary as claude-host (once) so --host can invoke it.
  local real_claude
  real_claude="$(command -v claude 2>/dev/null || true)"
  if [ -z "$real_claude" ]; then
    for _try in "$HOME/.claude/local/claude" "$HOME/.local/bin/claude" "/usr/local/bin/claude"; do
      if [ -x "$_try" ]; then real_claude="$_try"; break; fi
    done
  fi
  if [ -n "$real_claude" ]; then
    local claude_dir
    claude_dir="$(dirname "$real_claude")"
    # Resolve symlink to get the actual binary for the backup.
    local real_binary
    real_binary="$(readlink -f "$real_claude" 2>/dev/null || echo "$real_claude")"
    # Only back up if the resolved path is a real binary (not already a wrapper script).
    if ! head -1 "$real_binary" 2>/dev/null | rg -q "bash|sh"; then
      if [ ! -x "$claude_dir/claude-host" ]; then
        cp "$real_binary" "$claude_dir/claude-host"
        chmod +x "$claude_dir/claude-host"
        ok "claude binary backed up → $claude_dir/claude-host"
      else
        ok "claude-host already exists at $claude_dir/claude-host"
      fi
    fi
  else
    warn "claude binary not found — install Claude Code then re-run install.sh"
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

  # agent_bin must come before LOCAL_BIN so the wrapper shadows the real claude.
  _append_once 'local/share/ai-agent/bin' \
'# AI Agent Shell — added by install.sh
export PATH="$HOME/.local/share/ai-agent/bin:$HOME/.local/bin:$PATH"'

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
