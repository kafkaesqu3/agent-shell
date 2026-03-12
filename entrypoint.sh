#!/bin/bash
set -e

# Entrypoint runs as root so it can fix volume ownership before dropping to
# the agent user. Named volumes are initialised owned by root; without this
# chown the agent user cannot write config files into the mounted directory.

# --- Fix volume ownership (volume may be root-owned on first run) ---
chown -R agent:agent /home/agent/.config /workspace 2>/dev/null || true

# --- Persist ~/.claude.json across restarts via the named volume ---
# ~/.claude.json sits next to ~/.claude/ and is not covered by the volume mount,
# so it disappears on every container restart. We copy it in from the volume at
# startup and trap EXIT to write it back, keeping it as a plain file throughout.
CLAUDE_JSON_STORE=/home/agent/.claude/claude.json
CLAUDE_JSON=/home/agent/.claude.json
if [ -f "$CLAUDE_JSON_STORE" ]; then
  cp "$CLAUDE_JSON_STORE" "$CLAUDE_JSON"
else
  echo '{}' > "$CLAUDE_JSON"
fi
chown agent:agent "$CLAUDE_JSON"
trap 'cp -f "$CLAUDE_JSON" "$CLAUDE_JSON_STORE" 2>/dev/null || true' EXIT

# Config files are always overwritten from the baked image so that rebuilding
# the image is sufficient to pick up changes from claude-config/ in the repo.
# Only credentials and session state (history, projects) are preserved.

# --- Config files: always sync from image ---
if [ -f /opt/host-config/CLAUDE.md ]; then
  cp /opt/host-config/CLAUDE.md /home/agent/.claude/CLAUDE.md
else
  cp /opt/claude-config/CLAUDE.md /home/agent/.claude/CLAUDE.md
fi
cp /opt/claude-config/CLAUDE.*.md /home/agent/.claude/ 2>/dev/null || true
cp /opt/claude-config/settings.json /home/agent/.claude/settings.json
if [ -f /opt/claude-config/statusline.sh ]; then
  cp /opt/claude-config/statusline.sh /home/agent/.claude/statusline.sh
  chmod +x /home/agent/.claude/statusline.sh
fi

# --- Copy slash commands ---
if [ -d /opt/claude-config/commands ]; then
  mkdir -p /home/agent/.claude/commands
  cp /opt/claude-config/commands/*.md /home/agent/.claude/commands/
fi

# --- Copy hook scripts ---
if [ -d /opt/claude-config/hooks ]; then
  mkdir -p /home/agent/.claude/hooks
  cp /opt/claude-config/hooks/*.sh /home/agent/.claude/hooks/
  chmod +x /home/agent/.claude/hooks/*.sh
fi

# --- Copy agent definitions ---
if [ -d /opt/claude-config/agents ]; then
  mkdir -p /home/agent/.claude/agents
  cp /opt/claude-config/agents/*.md /home/agent/.claude/agents/
fi

# --- Patch MCP env var placeholders in settings.json ---
# Only needed for values embedded in URLs/strings (not MCP server env blocks,
# which inherit the container environment directly).
if [ -n "$BRIGHTDATA_API_KEY" ]; then
  sed -i "s|__BRIGHTDATA_API_KEY__|${BRIGHTDATA_API_KEY}|g" /home/agent/.claude/settings.json
fi

# --- Credentials: populate from host file or env var ---
# Host file always wins (ensures host re-auth propagates into the container).
# Env var is used in headless/CI deployments where no host file exists.
# If neither is available, existing credentials in the named volume are kept
# so that logging in interactively inside the container persists across runs.
if [ -f /opt/host-config/.credentials.json ]; then
  cp /opt/host-config/.credentials.json /home/agent/.claude/.credentials.json
  chmod 600 /home/agent/.claude/.credentials.json
elif [ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ] && [ ! -f /home/agent/.claude/.credentials.json ]; then
  cat > /home/agent/.claude/.credentials.json <<EOF
{
  "claudeAiOauth": {
    "token": "${CLAUDE_CODE_OAUTH_TOKEN}"
  }
}
EOF
  chmod 600 /home/agent/.claude/.credentials.json
fi

# --- Skill profiles: merge extra plugins into settings.json ---
# Starts with the default plugins baked into settings.json, then adds profiles
# from two sources (combined, deduplicated):
#   1. SKILL_PROFILES env var — explicit list e.g. "web,go"
#   2. Auto-detection — scans /workspace for well-known project files
PROFILES_FILE=/opt/claude-config/skill-profiles.json
if [ -f "$PROFILES_FILE" ]; then
  ACTIVE_PROFILES="${SKILL_PROFILES:-}"

  # Auto-detect workspace project type
  while IFS= read -r indicator; do
    path_to_check="/workspace/$indicator"
    if [ -e "$path_to_check" ]; then
      detected=$(jq -r --arg k "$indicator" '.autodetect[$k] // [] | join(",")' "$PROFILES_FILE")
      [ -n "$detected" ] && ACTIVE_PROFILES="${ACTIVE_PROFILES:+$ACTIVE_PROFILES,}$detected"
    fi
  done < <(jq -r '.autodetect | keys[]' "$PROFILES_FILE")

  if [ -n "$ACTIVE_PROFILES" ]; then
    # Build {plugin: true} map for all plugins in the selected profiles
    EXTRA=$(jq -n \
      --arg profiles "$ACTIVE_PROFILES" \
      --slurpfile sp "$PROFILES_FILE" '
        ($profiles | split(",") | map(ltrimstr(" ") | rtrimstr(" "))) as $names |
        $sp[0].profiles as $p |
        [$names[] | $p[.] // []] | flatten | unique |
        map({key: ., value: true}) | from_entries
      ')
    jq --argjson extra "$EXTRA" '.enabledPlugins += $extra' \
      /home/agent/.claude/settings.json > /tmp/settings.json.tmp \
      && mv /tmp/settings.json.tmp /home/agent/.claude/settings.json
    echo "Skills loaded: $ACTIVE_PROFILES" >&2
  fi
fi

# --- Conditionally strip browser MCP servers if not in browsing image ---
if ! command -v chromium &>/dev/null && [ -f /home/agent/.claude/settings.json ]; then
  # Remove puppeteer and playwright entries since browser isn't available
  jq 'del(.mcpServers.puppeteer, .mcpServers.playwright)' /home/agent/.claude/settings.json > /tmp/settings.json.tmp \
    && mv /tmp/settings.json.tmp /home/agent/.claude/settings.json 2>/dev/null || true
fi

# --- Fix ownership after all copies (cp runs as root, so new files are root-owned) ---
chown -R agent:agent /home/agent/.claude 2>/dev/null || true

# --- Lock down permissions on .claude directory ---
chmod -R 700 /home/agent/.claude 2>/dev/null || true

# --- Drop to agent user and hand off to the requested command ---
# No exec — shell must stay alive so the EXIT trap fires and saves ~/.claude.json
gosu agent "$@"
