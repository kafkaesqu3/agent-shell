#!/usr/bin/env bash
# install_agents: copy Claude Code agent definitions to ~/.claude/agents/
set -euo pipefail
# shellcheck source=install/common.sh
[[ -z "${SCRIPT_DIR:-}" ]] && source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/install/common.sh"

install_agents() {
  echo -e "${BOLD}--- Installing Claude Code Agents ---${NC}"

  local src="$SCRIPT_DIR/claude-config/agents"
  local dst="$CLAUDE_HOME/agents"

  if [[ ! -d "$src" ]]; then
    warn "claude-config/agents/ not found — skipping"
    return
  fi

  if ! grep -q 'CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS' "$CLAUDE_HOME/settings.json" 2>/dev/null; then
    warn "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS not set in settings.json — run --config first or agents may not activate"
  fi

  mkdir -p "$dst"

  shopt -s nullglob
  local agent_files=("$src"/*.md)
  shopt -u nullglob

  if [[ ${#agent_files[@]} -eq 0 ]]; then
    warn "No agent files found in $src"
    return
  fi

  for src_file in "${agent_files[@]}"; do
    local name
    name=$(basename "$src_file")
    local dst_file="$dst/$name"

    if [[ -f "$dst_file" ]]; then
      ok "  $name already exists — skipping (local copy preserved)"
    else
      cp "$src_file" "$dst_file"
      ok "  $name installed"
    fi
  done

  echo ""
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/install/common.sh"
  install_agents
fi
