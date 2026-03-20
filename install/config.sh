#!/usr/bin/env bash
# install_config: copy Claude Code config files to ~/.claude
set -euo pipefail
# shellcheck source=install/common.sh
[[ -z "${SCRIPT_DIR:-}" ]] && source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/install/common.sh"

_install_claude_binary() {
  if cmd_exists claude; then
    ok "Claude Code already installed ($(claude --version 2>/dev/null || echo 'unknown version'))"
  else
    info "Installing Claude Code..."
    curl -fsSL https://claude.ai/install.sh | bash 2>&1 | tail -3
    ok "Claude Code installed"
  fi

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

install_config() {
  echo -e "${BOLD}--- Claude Code Configuration ---${NC}"

  _install_claude_binary

  mkdir -p "$CLAUDE_HOME"

  # --- settings.json: merge MCP servers ---
  local repo_settings="$SCRIPT_DIR/claude-config/settings.json"
  local host_settings="$CLAUDE_HOME/settings.json"

  if [ -f "$host_settings" ]; then
    info "Merging repo settings into existing $host_settings"
    # Repo is the base; preserve user-specific overrides: model, plugins, UI prefs, attribution.
    # For mcpServers, repo provides the schema but host values win — preserves already-substituted
    # tokens on re-runs so __PLACEHOLDER__ strings never overwrite real tokens.
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
      sed_i "s|__BRIGHTDATA_API_KEY__|${BRIGHTDATA_API_KEY}|g" "$merged"

    cp "$host_settings" "${host_settings}.bak"
    mv "$merged" "$host_settings"
    ok "Settings merged (backup at settings.json.bak)"
  else
    info "No existing settings.json — copying from repo"
    cp "$repo_settings" "$host_settings"
    [ -n "${BRIGHTDATA_API_KEY:-}" ] && \
      sed_i "s|__BRIGHTDATA_API_KEY__|${BRIGHTDATA_API_KEY}|g" "$host_settings"
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
    shopt -s nullglob
    local hook_files=("$SCRIPT_DIR/claude-config/hooks"/*.sh)
    shopt -u nullglob
    if [ ${#hook_files[@]} -gt 0 ]; then
      cp "${hook_files[@]}" "$CLAUDE_HOME/hooks/"
      chmod +x "$CLAUDE_HOME/hooks/"*.sh
      ok "hook scripts installed to $CLAUDE_HOME/hooks/"
    fi
  else
    warn "hooks/ directory not found in repo — skipping"
  fi

  echo ""
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/install/common.sh"
  install_config
fi
