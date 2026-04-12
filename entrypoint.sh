#!/usr/bin/env bash
set -euo pipefail

# Entrypoint runs as root so it can fix volume ownership before dropping to
# the agent user. Named volumes are initialised owned by root; without this
# chown the agent user cannot write config files into the mounted directory.

# --- Remap agent UID/GID to match the host user (prevents bind-mount ownership corruption) ---
# ai-agent.sh passes HOST_UID / HOST_GID from $(id -u) / $(id -g) on the host.
HOST_UID=${HOST_UID:-1000}
HOST_GID=${HOST_GID:-1000}
if [ "$(id -u agent)" != "$HOST_UID" ] || [ "$(id -g agent)" != "$HOST_GID" ]; then
    groupmod -g "$HOST_GID" agent 2>/dev/null || true
    usermod  -u "$HOST_UID" agent 2>/dev/null || true
fi

# --- Fix volume ownership (volume may be root-owned on first run) ---
# Named volumes are initialised owned by root; chown so agent can write config.
# /workspace is NOT chowned: on Windows/macOS, Docker Desktop mounts bind paths
# with 0777 so agent can write without owning them; on Linux the host UID matches
# the container UID directly.
chown -R agent:agent /home/agent/.config 2>/dev/null || true

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
# Recover from a corrupted claude.json (e.g. container killed mid-write)
if ! jq empty "$CLAUDE_JSON" 2>/dev/null; then
  echo "Warning: corrupted claude.json detected, resetting to empty" >&2
  echo '{}' > "$CLAUDE_JSON"
fi
chown agent:agent "$CLAUDE_JSON"
trap 'cp -f "$CLAUDE_JSON" "$CLAUDE_JSON_STORE" 2>/dev/null || true' EXIT

# --- Seed new workspace from golden image snapshot (no-clobber) ---
# cp -rn skips files that already exist, so evolved workspaces are never overwritten.
# New files added to the image snapshot propagate to existing workspaces on next start.
if [ -d /opt/claude-seed ]; then
  cp -rn /opt/claude-seed/. /home/agent/.claude/
fi

# --- Write .gitignore for workspace .agent/ directory (first run only) ---
if [ ! -f /home/agent/.claude/.gitignore ]; then
  cat > /home/agent/.claude/.gitignore << 'GITIGNORE'
# Sensitive credentials — never commit
.credentials.json
claude.json

# Caches — large, auto-downloaded
plugins/
statsig/
GITIGNORE
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

# --- Onboarding bypass (https://github.com/anthropics/claude-code/issues/8938) ---
# Claude Code shows an interactive wizard on first run if ~/.claude.json has no
# hasCompletedOnboarding flag. When a token is available, seed the flag and run
# a throwaway prompt once so the container starts non-interactively every time.
#
# Token source priority:
#   1. CLAUDE_CODE_OAUTH_TOKEN env var (headless/CI)
#   2. Host credentials file (mounted via ai-agent.sh/.ps1)
_BYPASS_TOKEN="${CLAUDE_CODE_OAUTH_TOKEN:-}"
if [ -z "$_BYPASS_TOKEN" ] && [ -f /opt/host-config/.credentials.json ]; then
  _BYPASS_TOKEN=$(jq -r '.claudeAiOauth.accessToken // empty' /opt/host-config/.credentials.json 2>/dev/null || true)
fi

if [ -n "$_BYPASS_TOKEN" ]; then
  ONBOARDING_DONE=$(jq -r '.hasCompletedOnboarding // false' "$CLAUDE_JSON" 2>/dev/null || echo "false")
  if [ "$ONBOARDING_DONE" != "true" ]; then
    tmp=$(mktemp)
    jq --arg tok "$_BYPASS_TOKEN" \
      '.oauthAccount.accessToken = $tok | .hasCompletedOnboarding = true' \
      "$CLAUDE_JSON" > "$tmp" && mv "$tmp" "$CLAUDE_JSON"
    chown agent:agent "$CLAUDE_JSON"
    # Run a throwaway prompt to populate initial config state (runs once per volume)
    gosu agent claude -p "ok" --output-format json >/dev/null 2>&1 || true
    # Re-apply flag in case claude rewrote the file without it
    tmp=$(mktemp)
    jq '.hasCompletedOnboarding = true' "$CLAUDE_JSON" > "$tmp" && mv "$tmp" "$CLAUDE_JSON"
    chown agent:agent "$CLAUDE_JSON"
  fi
fi

# --- MCP servers: register into ~/.claude.json ---
# mcp-servers.json is the source of truth (native .mcp.json format).
# Each image bakes only the servers it supports (browsing adds puppeteer/playwright).
# Substitute placeholders, drop unresolved entries, write to both:
#   - top-level mcpServers (for when Anthropic fixes the user-scope bug)
#   - projects["/workspace"].mcpServers (workaround: Claude reads project-level entries)
# This block runs after onboarding so claude -p "ok" cannot overwrite these entries.
# Project-specific .mcp.json files in /workspace still work alongside these.
MCP_FILE=/opt/claude-config/mcp-servers.json
if [ -f "$MCP_FILE" ]; then
  mcp_raw=$(cat "$MCP_FILE")
  [ -n "${BRIGHTDATA_API_KEY:-}" ] && \
    mcp_raw=$(printf '%s' "$mcp_raw" | sed "s|__BRIGHTDATA_API_KEY__|${BRIGHTDATA_API_KEY}|g")
  [ -n "${EXA_API_KEY:-}" ] && \
    mcp_raw=$(printf '%s' "$mcp_raw" | sed "s|__EXA_API_KEY__|${EXA_API_KEY}|g")

  # Drop any entry with an unresolved placeholder
  mcp_filter='.mcpServers | to_entries | map(select(.value | tostring | test("__[A-Z_]+__") | not)) | from_entries'

  mcp_servers=$(printf '%s' "$mcp_raw" | jq "$mcp_filter")
  tmp=$(mktemp)
  # Write servers to user-scope top-level mcpServers.
  # Also remove empty mcpServers ({}) from any project entries — Claude Code uses project-level
  # mcpServers as an override and an empty {} silently shadows the global user-scope servers.
  jq --argjson mcp "$mcp_servers" '
    .mcpServers = $mcp |
    if .projects then
      .projects |= with_entries(
        if (.value.mcpServers // {}) == {} then del(.value.mcpServers) else . end
      )
    else . end
  ' "$CLAUDE_JSON" > "$tmp" && mv "$tmp" "$CLAUDE_JSON"
  chown agent:agent "$CLAUDE_JSON"
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

# --- Fix ownership after all copies (cp runs as root, so new files are root-owned) ---
chown -R agent:agent /home/agent/.claude 2>/dev/null || true

# --- Lock down permissions on .claude directory ---
chmod -R 700 /home/agent/.claude 2>/dev/null || true

# --- Unset build-time npm hardening env vars ---
# These are set in the Dockerfile for supply-chain security during image builds,
# but Docker ENV persists into the running container. At runtime they break npx
# installs: IGNORE_SCRIPTS suppresses lifecycle scripts that finalize package
# dist files, and MINIMUM_RELEASE_AGE can silently reject recent transitive deps.
unset NPM_CONFIG_IGNORE_SCRIPTS NPM_CONFIG_MINIMUM_RELEASE_AGE

# --- Drop to agent user and hand off to the requested command ---
# No exec — shell must stay alive so the EXIT trap fires and saves ~/.claude.json
gosu agent "$@"
