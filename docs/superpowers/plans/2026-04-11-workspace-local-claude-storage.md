# Workspace-Local Claude Storage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the global `ai-agent-claude` named Docker volume with a per-project named volume plus a workspace bind mount for conversation history, so that history/memories are accessible as files in the workspace while credentials stay in the volume.

**Architecture:** Each container gets a per-project named volume `ai-agent-claude-<name>` for all state except conversation history. A second bind mount overlaps `/home/agent/.claude/projects/` pointing to `$(pwd)/.agent/` on the host. Docker overlapping mount semantics mean the bind mount takes precedence for that subpath.

**Tech Stack:** Bash, PowerShell, Docker

---

## File Map

| File | Change |
|------|--------|
| `ai-agent.sh` | Remove `VOLUME_NAME` constant and `sync` subcommand; add per-project volume name derivation; add `mkdir -p .agent`; add bind mount for `projects/` |
| `ai-agent.ps1` | Same changes, PowerShell syntax |
| `docs/superpowers/specs/2026-04-11-workspace-local-claude-storage-design.md` | Already updated to final design |

`entrypoint.sh` — no changes needed.

---

### Task 1: Update `ai-agent.sh`

**Files:**
- Modify: `ai-agent.sh`

The goal is three concrete changes:
1. Remove the `VOLUME_NAME` constant at the top (line 8)
2. Remove the `sync` subcommand block and all references to it
3. Replace the volume mount with a per-project volume + bind mount

**Current sync block (lines 127–147) to remove:**
```bash
if [[ "${1:-}" == "sync" ]]; then
    if [ -z "$CONTAINER_NAME" ]; then
        CONTAINER_NAME="$(basename "$(pwd)")"
    fi
    if ! docker info > /dev/null 2>&1; then
        echo -e "${RED}Docker is not running!${NC}"; exit 1
    fi
    mkdir -p "$HOME/.claude/projects"
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$" 2>/dev/null; then
        echo -e "${BLUE}Syncing from running container: $CONTAINER_NAME${NC}"
    elif docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$" 2>/dev/null; then
        echo -e "${BLUE}Syncing from stopped container: $CONTAINER_NAME${NC}"
    else
        echo -e "${RED}Container not found: $CONTAINER_NAME${NC}"
        echo "Specify with --name, or run from the project directory (container is named after the directory)"
        exit 1
    fi
    docker cp "${CONTAINER_NAME}:/home/agent/.claude/projects/." "$HOME/.claude/projects/" 2>/dev/null || true
    echo -e "${GREEN}Session logs synced to ~/.claude/projects/${NC}"
    exit 0
fi
```

- [ ] **Step 1: Remove `VOLUME_NAME` constant**

Open `ai-agent.sh`. Delete line 8:
```bash
VOLUME_NAME="ai-agent-claude"
```
(The constant is replaced by inline derivation later in the file.)

- [ ] **Step 2: Remove `sync` from usage text**

In the `usage()` function, remove the sync-related lines:
```
  sync                Copy session logs from container to ~/.claude/projects/
```
and:
```
  ai-agent.sh --name myproject sync  # sync logs from named container
```

- [ ] **Step 3: Remove `sync` subcommand block**

Remove the entire `if [[ "${1:-}" == "sync" ]]; then ... fi` block (currently around lines 127–147 after the constant removal). The block starts with `# Handle subcommands` and ends with `exit 0`.

Also remove the comment line `# Handle subcommands` immediately above it.

- [ ] **Step 4: Replace volume mount with per-project volume + bind mount**

Find the `# Volumes` section (currently around line 284):
```bash
# Volumes
DOCKER_ARGS+=("-v" "$(pwd):/workspace")
DOCKER_ARGS+=("-v" "$VOLUME_NAME:/home/agent/.claude")
```

Replace it with:
```bash
# Volumes
_CLAUDE_VOL="ai-agent-claude-${CONTAINER_NAME:-$(basename "$(pwd)")}"
mkdir -p "$(pwd)/.agent"
DOCKER_ARGS+=("-v" "$(pwd):/workspace")
DOCKER_ARGS+=("-v" "${_CLAUDE_VOL}:/home/agent/.claude")
DOCKER_ARGS+=("-v" "$(pwd)/.agent:/home/agent/.claude/projects")
```

- [ ] **Step 5: Verify the script is valid shell**

```bash
shellcheck ai-agent.sh
```

Expected: no errors. Fix any issues before continuing.

- [ ] **Step 6: Commit**

```bash
git add ai-agent.sh
git commit -m "feat: scope claude storage to workspace via per-project volume and bind mount"
```

---

### Task 2: Update `ai-agent.ps1`

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

Remove the entire `if ($PassArgs.Count -gt 0 -and $PassArgs[0] -eq "sync") { ... }` block (currently around lines 113–138). It starts with `# Handle subcommands` and ends after `exit 0`.

Also remove the `# Handle subcommands` comment line above it.

- [ ] **Step 4: Replace volume mount with per-project volume + bind mount**

Find the `# Volumes` section (currently around line 282):
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
$VolSuffix = if ($ContainerName) { $ContainerName } else { Split-Path -Leaf (Get-Location) }
$ClaudeVol = "ai-agent-claude-$VolSuffix"
$null = New-Item -ItemType Directory -Force -Path (Join-Path $CurrentDir ".agent")
$DockerArgs += "-v"; $DockerArgs += "${CurrentDir}:/workspace"
$DockerArgs += "-v"; $DockerArgs += "${ClaudeVol}:/home/agent/.claude"
$DockerArgs += "-v"; $DockerArgs += "${CurrentDir}\.agent:/home/agent/.claude/projects"
```

- [ ] **Step 5: Commit**

```bash
git add ai-agent.ps1
git commit -m "feat: scope claude storage to workspace in PowerShell launcher"
```

---

### Task 3: Commit updated spec

**Files:**
- Modify: `docs/superpowers/specs/2026-04-11-workspace-local-claude-storage-design.md` (already updated)

- [ ] **Step 1: Commit the spec update**

```bash
git add docs/superpowers/specs/2026-04-11-workspace-local-claude-storage-design.md
git commit -m "docs: update storage design spec to final design"
```

---

### Task 4: Manual Verification

No automated tests exist for Docker launcher scripts. Verify the change works end-to-end.

- [ ] **Step 1: Check `.agent/` is created on launch**

From any project directory, run:
```bash
./ai-agent.sh --rm
```
Expected: `.agent/` directory is created in the current directory before docker starts.

- [ ] **Step 2: Check per-project volume is created**

```bash
docker volume ls | grep ai-agent-claude
```
Expected: `ai-agent-claude-<dirname>` appears. The old `ai-agent-claude` global volume does NOT appear as a new entry.

- [ ] **Step 3: Check history lands in `.agent/`**

Inside the container, run a short Claude session:
```bash
claude -p "say hello"
```
Then exit the container and check:
```bash
ls .agent/projects/
```
Expected: a subdirectory exists (named after `/workspace` path, URL-encoded).

- [ ] **Step 4: Check credentials are NOT in `.agent/`**

```bash
ls .agent/.credentials.json 2>/dev/null && echo "FAIL - credentials in workspace" || echo "OK - credentials not in workspace"
ls .agent/claude.json 2>/dev/null && echo "FAIL - claude.json in workspace" || echo "OK - claude.json not in workspace"
```
Expected: both print `OK`.

- [ ] **Step 5: Check history persists across container restarts**

```bash
# From the same project directory
./ai-agent.sh --rm
# Inside: run claude -p "remember the number 42"
# Exit container
./ai-agent.sh --rm
# Inside: run claude -p "what number did I ask you to remember?"
```
Expected: second session has no memory of the first (Claude has no cross-session recall by default),
but the `.agent/projects/` directory contains both session logs from the first run.

- [ ] **Step 6: Check isolation between two projects**

```bash
mkdir /tmp/project-a /tmp/project-b
cd /tmp/project-a && ./path/to/ai-agent.sh --rm   # start session in project-a
# Inside: run claude -p "hello from project a"
# Exit
cd /tmp/project-b && ./path/to/ai-agent.sh --rm   # start session in project-b
```
Expected:
- `/tmp/project-a/.agent/projects/` contains project-a history
- `/tmp/project-b/.agent/projects/` is empty or only contains project-b history
- `docker volume ls` shows `ai-agent-claude-project-a` and `ai-agent-claude-project-b` as separate volumes
