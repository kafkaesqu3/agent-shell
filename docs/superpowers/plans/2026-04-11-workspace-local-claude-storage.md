# Workspace-Local Claude Storage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the global `ai-agent-claude` named Docker volume with a per-workspace bind mount so that each project's Claude config, history, and memories live in `$(pwd)/.agent/`, seeded from a golden image on first run.

**Architecture:** The Dockerfile snapshots the baked `/home/agent/.claude/` (including plugins) to `/opt/claude-seed/` after installation. The entrypoint seeds new workspaces from this snapshot using `cp -rn` (no-clobber), so existing workspaces are never overwritten. Launchers replace the named volume with `$(pwd)/.agent:/home/agent/.claude`.

**Tech Stack:** Bash, PowerShell, Docker, jq

---

## File Map

| File | Change |
|------|--------|
| `Dockerfile` | Add seed snapshot after plugin installation |
| `entrypoint.sh` | Add seed step + gitignore; remove per-file cp calls |
| `ai-agent.sh` | Bind mount; remove named volume + host config mounts + sync |
| `ai-agent.ps1` | Same changes in PowerShell |

---

### Task 1: Add seed snapshot to Dockerfile

**Files:**
- Modify: `Dockerfile`

The named volume currently auto-seeds from the image (Docker behaviour). Bind mounts don't.
We need to snapshot the baked `/home/agent/.claude/` content (including plugins) to
`/opt/claude-seed/` so the entrypoint can seed new workspaces.

- [ ] **Step 1: Find the right insertion point**

Read `Dockerfile`. The plugin install block ends around line 92 with the closing `'`. The
snapshot must happen AFTER plugin installation but BEFORE the `WORKDIR /workspace` line.

- [ ] **Step 2: Add the snapshot**

After the closing `'` of the plugin install `RUN` block (after line 92), add:

```dockerfile
# Snapshot baked .claude/ (plugins + initial config) so entrypoint can seed new workspaces.
# Bind mounts don't auto-seed from image content the way named volumes do.
RUN cp -r /home/agent/.claude /opt/claude-seed
```

- [ ] **Step 3: Verify Dockerfile syntax**

```bash
docker build --target lite -t ai-agent:lite-test . 2>&1 | tail -5
```

Expected: build succeeds (or fails only at transient network steps, not syntax errors).

- [ ] **Step 4: Verify snapshot exists in image**

```bash
docker run --rm ai-agent:lite-test ls /opt/claude-seed/
```

Expected: output includes `plugins/` and any config files baked during build.

- [ ] **Step 5: Commit**

```bash
git add Dockerfile
git commit -m "feat: snapshot baked .claude/ to /opt/claude-seed for workspace seeding"
```

---

### Task 2: Update entrypoint.sh

**Files:**
- Modify: `entrypoint.sh`

Three changes:
1. Add seed step (replaces individual per-file cp calls)
2. Add auto-gitignore
3. Remove the individual `cp /opt/claude-config/...` calls for config files

- [ ] **Step 1: Read the current entrypoint**

Read `entrypoint.sh` in full. Note the section labelled `# --- Config files: always sync from image ---` (around line 47). This is the block to replace.

- [ ] **Step 2: Replace the config copy block with seed step + gitignore**

Remove the entire `# --- Config files: always sync from image ---` section:
```bash
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
```

And remove the subsequent `# --- Copy slash commands ---`, `# --- Copy hook scripts ---`,
and `# --- Copy agent definitions ---` sections:
```bash
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
  cp /opt/claude-config/agents/*.md /home/agent/.claude/agents/ 2>/dev/null || true
fi
```

Replace the entire removed block with:
```bash
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
```

Also remove the dotfile sync section:
```bash
# --- Sync shell and tmux dotfiles ---
[ -f /opt/claude-config/zshrc     ] && cp /opt/claude-config/zshrc     /home/agent/.zshrc
[ -f /opt/claude-config/tmux.conf ] && cp /opt/claude-config/tmux.conf /home/agent/.tmux.conf
```
These dotfiles are already baked into the image directly (Dockerfile `COPY` lines) — the
entrypoint sync was redundant.

- [ ] **Step 3: Verify entrypoint is valid shell**

```bash
shellcheck entrypoint.sh
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add entrypoint.sh
git commit -m "feat: seed workspace from image snapshot instead of always-overwrite config copy"
```

---

### Task 3: Update `ai-agent.sh`

**Files:**
- Modify: `ai-agent.sh`

Four changes:
1. Remove `VOLUME_NAME` constant
2. Remove host CLAUDE.md and settings.json override mounts (workspace owns config)
3. Replace named volume with bind mount; add `mkdir -p .agent`
4. Remove `sync` subcommand

- [ ] **Step 1: Remove `VOLUME_NAME` constant**

Delete line 8:
```bash
VOLUME_NAME="ai-agent-claude"
```

- [ ] **Step 2: Remove `sync` from usage text**

In the `usage()` function, remove:
```
  sync                Copy session logs from container to ~/.claude/projects/
```
and:
```
  ai-agent.sh --name myproject sync  # sync logs from named container
```

- [ ] **Step 3: Remove the `sync` subcommand block**

Remove the entire `# Handle subcommands` comment and the `if [[ "${1:-}" == "sync" ]]; then ... fi` block that follows it (around lines 127–147 of the original).

- [ ] **Step 4: Remove host CLAUDE.md and settings.json override mounts**

Find and remove these two blocks:
```bash
# Optional: host CLAUDE.md override (staged for entrypoint processing)
if [ -f "$CLAUDE_HOME/CLAUDE.md" ]; then
    DOCKER_ARGS+=("-v" "$CLAUDE_HOME/CLAUDE.md:/opt/host-config/CLAUDE.md:ro")
    echo -e "${GREEN}Mounting host CLAUDE.md${NC}"
fi

# Optional: host settings.json override
if [ -f "$CLAUDE_HOME/settings.json" ]; then
    DOCKER_ARGS+=("-v" "$CLAUDE_HOME/settings.json:/opt/host-config/settings.json:ro")
    echo -e "${GREEN}Mounting host settings.json${NC}"
fi
```

Keep the credentials mount — it is still needed:
```bash
# Optional: host credentials — staged outside the named volume so the
# entrypoint can copy them in (bind-mounting a file inside a named-volume
# directory is unreliable; the volume wins).
if [ -f "$CLAUDE_HOME/.credentials.json" ]; then
    DOCKER_ARGS+=("-v" "$CLAUDE_HOME/.credentials.json:/opt/host-config/.credentials.json:ro")
    echo -e "${GREEN}Mounting host credentials${NC}"
fi
```

- [ ] **Step 5: Replace named volume with bind mount**

Find the `# Volumes` section:
```bash
# Volumes
DOCKER_ARGS+=("-v" "$(pwd):/workspace")
DOCKER_ARGS+=("-v" "$VOLUME_NAME:/home/agent/.claude")
```

Replace with:
```bash
# Volumes
mkdir -p "$(pwd)/.agent"
DOCKER_ARGS+=("-v" "$(pwd):/workspace")
DOCKER_ARGS+=("-v" "$(pwd)/.agent:/home/agent/.claude")
```

- [ ] **Step 6: Verify**

```bash
shellcheck ai-agent.sh
```

Expected: no errors.

- [ ] **Step 7: Commit**

```bash
git add ai-agent.sh
git commit -m "feat: replace named volume with workspace bind mount in bash launcher"
```

---

### Task 4: Update `ai-agent.ps1`

**Files:**
- Modify: `ai-agent.ps1`

Mirror the same changes in PowerShell.

- [ ] **Step 1: Remove `$VolumeName` constant**

Delete line 13:
```powershell
$VolumeName = "ai-agent-claude"
```

- [ ] **Step 2: Remove `sync` from usage text**

In `Show-Usage`, remove:
```
  sync                Copy session logs from container to ~\.claude\projects\
```
and:
```
  .\ai-agent.ps1 --name myproject sync     # sync logs from named container
```

- [ ] **Step 3: Remove `sync` subcommand block**

Remove the `# Handle subcommands` comment and the entire
`if ($PassArgs.Count -gt 0 -and $PassArgs[0] -eq "sync") { ... }` block.

- [ ] **Step 4: Remove host CLAUDE.md and settings.json override mounts**

Find and remove:
```powershell
# Optional: host CLAUDE.md override (staged for entrypoint processing)
$ClaudeMd = Join-Path $ClaudeHome "CLAUDE.md"
if (Test-Path $ClaudeMd) {
    $DockerArgs += "-v"; $DockerArgs += "${ClaudeMd}:/opt/host-config/CLAUDE.md:ro"
    Write-Host "Mounting host CLAUDE.md" -ForegroundColor Green
}

# Optional: host settings.json override (staged for entrypoint processing)
$ClaudeSettings = Join-Path $ClaudeHome "settings.json"
if (Test-Path $ClaudeSettings) {
    $DockerArgs += "-v"; $DockerArgs += "${ClaudeSettings}:/opt/host-config/settings.json:ro"
    Write-Host "Mounting host settings.json" -ForegroundColor Green
}
```

Keep the credentials mount.

- [ ] **Step 5: Replace named volume with bind mount**

Find the `# Volumes` section:
```powershell
# Volumes
$CurrentDir = (Get-Location).Path
$DockerArgs += "-v"; $DockerArgs += "${CurrentDir}:/workspace"
$DockerArgs += "-v"; $DockerArgs += "${VolumeName}:/home/agent/.claude"
```

Replace with:
```powershell
# Volumes
$CurrentDir = (Get-Location).Path
$null = New-Item -ItemType Directory -Force -Path (Join-Path $CurrentDir ".agent")
$DockerArgs += "-v"; $DockerArgs += "${CurrentDir}:/workspace"
$DockerArgs += "-v"; $DockerArgs += "${CurrentDir}\.agent:/home/agent/.claude"
```

- [ ] **Step 6: Commit**

```bash
git add ai-agent.ps1
git commit -m "feat: replace named volume with workspace bind mount in PowerShell launcher"
```

---

### Task 5: Manual Verification

- [ ] **Step 1: Build the image**

```bash
docker build --target lite -t ai-agent:lite .
```

Expected: build completes. Verify `/opt/claude-seed/` exists and contains `plugins/`:
```bash
docker run --rm ai-agent:lite ls /opt/claude-seed/
```

- [ ] **Step 2: First run — verify seeding**

```bash
cd /tmp && mkdir test-workspace && cd test-workspace
/path/to/ai-agent.sh --rm --lite
```

Inside container:
```bash
ls ~/.claude/plugins/   # should have superpowers, hookify etc.
ls ~/.claude/settings.json   # should exist
exit
```

On host:
```bash
ls /tmp/test-workspace/.agent/   # should mirror what was in ~/.claude/
ls /tmp/test-workspace/.agent/.gitignore   # should exist
cat /tmp/test-workspace/.agent/.gitignore
```

- [ ] **Step 3: Second run — verify workspace config persists (not overwritten)**

```bash
echo "# my custom addition" >> /tmp/test-workspace/.agent/CLAUDE.md
cd /tmp/test-workspace && /path/to/ai-agent.sh --rm --lite
```

Inside container:
```bash
tail -1 ~/.claude/CLAUDE.md   # should show "# my custom addition"
exit
```

- [ ] **Step 4: Verify credentials not in workspace**

```bash
ls /tmp/test-workspace/.agent/.credentials.json 2>/dev/null \
  && echo "FAIL" || echo "OK — credentials not in workspace"
```

Expected: `OK`.

- [ ] **Step 5: Verify isolation between workspaces**

```bash
mkdir /tmp/workspace-b && cd /tmp/workspace-b
/path/to/ai-agent.sh --rm --lite
```

Expected: `/tmp/workspace-b/.agent/` is seeded fresh — does NOT contain any history or
customisations from `/tmp/test-workspace/.agent/`.
