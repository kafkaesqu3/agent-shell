# Workspace-Local Claude Storage

**Date:** 2026-04-11
**Status:** Approved (final)

## Problem

The global named Docker volume `ai-agent-claude` is shared across every container from every
project. Conversation history from one workspace is visible when working in another. Config
cannot evolve per-project. There is no way to version-control a workspace's Claude setup
alongside its code.

## Goal

1. **Golden config** — `claude-config/` in the repo provides a standard baseline that every new
   workspace starts from.
2. **Per-workspace evolution** — each workspace can evolve its own config (settings, CLAUDE.md,
   hooks, commands, agents, memories, history) independently, stored in `.agent/` inside the
   project directory.
3. **Self-contained workspace** — the workspace directory holds both code and Claude config.
   Sensitive files (credentials, session tokens) never touch the workspace filesystem.

## Design

### Volume Strategy

Replace the named volume with a single bind mount:

```
$(pwd)/.agent/   →   /home/agent/.claude/   (inside container)
```

No named volume. All Claude data lives in the workspace.

### First-Run Seeding (Golden Config)

Docker named volumes auto-inherit image content on first use. Bind mounts do not — they
overlay the host directory, hiding image content entirely. Plugins baked into the image at
`/home/agent/.claude/plugins/` would be invisible behind an empty bind mount.

**Solution:** After plugin installation, the Dockerfile snapshots the full baked
`/home/agent/.claude/` to `/opt/claude-seed/`. The entrypoint seeds new workspaces from
this snapshot using `cp -rn` (no-clobber).

```dockerfile
# After plugin installation in Dockerfile:
RUN cp -r /home/agent/.claude /opt/claude-seed
```

```bash
# In entrypoint.sh — seeds new workspace, skips existing files in evolved workspaces:
cp -rn /opt/claude-seed/. /home/agent/.claude/
```

This means:
- **New workspace:** gets all plugins, settings, hooks, CLAUDE.md from the golden image
- **Existing workspace:** seed step skips all existing files; only new files added to the
  image snapshot are copied in

### What Is Visible in the Workspace

Everything in `/home/agent/.claude/` maps directly to `$(pwd)/.agent/` on the host:

| Path in `.agent/` | Contents | Commit to git? |
|-------------------|----------|----------------|
| `settings.json` | Claude Code settings (plugins, permissions) | Yes |
| `CLAUDE.md`, `CLAUDE.*.md` | Global dev instructions | Yes |
| `commands/` | Slash commands | Yes |
| `hooks/` | Pre/post-tool-use hooks | Yes |
| `agents/` | Agent definitions | Yes |
| `projects/` | Conversation history + memories | Optional |
| `todos/` | Todos | Optional |
| `plugins/` | Plugin cache (large, auto-downloaded) | No — gitignored |
| `statsig/` | Analytics cache | No — gitignored |
| `.credentials.json` | OAuth credentials | No — gitignored |
| `claude.json` | Session state / OAuth token copy | No — gitignored |

### Auto-Gitignore

The entrypoint writes `.agent/.gitignore` on every startup if the file does not already exist
(so users can customize it):

```gitignore
# Sensitive credentials — never commit
.credentials.json
claude.json

# Caches — large, auto-downloaded
plugins/
statsig/
```

### Entrypoint Changes

Current behaviour: individual `cp /opt/claude-config/<file>` calls always overwrite config.

New behaviour:
1. `cp -rn /opt/claude-seed/. /home/agent/.claude/` — seed new workspace (no-clobber)
2. Write `.gitignore` if not present
3. Remove individual config `cp` calls (replaced by seed step)
4. **Keep:** credentials always-overwrite from `/opt/host-config/.credentials.json`
5. **Keep:** `claude.json` copy-in/copy-out (Claude Code writes to `~/.claude.json` adjacent
   to `~/.claude/`, not inside it — the entrypoint bridges these paths unchanged)
6. **Keep:** onboarding bypass
7. **Keep:** MCP injection into `claude.json`
8. **Keep:** skill profiles merge into `settings.json`
9. **Keep:** chown/chmod at end

The host CLAUDE.md and settings.json override mounts in the launchers are removed — the
workspace owns its config after seeding. Only credentials continue to come from the host.

### Launcher Changes (`ai-agent.sh` and `ai-agent.ps1`)

1. Remove `VOLUME_NAME="ai-agent-claude"` constant
2. Remove host CLAUDE.md and settings.json override volume mounts (workspace owns config)
3. Keep credentials override mount (always needed)
4. Replace volume mount with bind mount:
   - Remove: `-v "ai-agent-claude:/home/agent/.claude"`
   - Add: `mkdir -p "$(pwd)/.agent"` before docker run
   - Add: `-v "$(pwd)/.agent:/home/agent/.claude"`
5. Remove `sync` subcommand (history is already in the workspace)

### `claude.json` Handling

Unchanged. Claude Code writes session state to `~/.claude.json` (adjacent to `~/.claude/`).
The entrypoint copies it in from `~/.claude/claude.json` at start and copies it back at exit.
The backing store (`~/.claude/claude.json` = `$(pwd)/.agent/claude.json`) now lives in the
workspace bind mount and persists naturally.

## Files Changed

| File | Change |
|------|--------|
| `Dockerfile` | Add `RUN cp -r /home/agent/.claude /opt/claude-seed` after plugin install |
| `entrypoint.sh` | Add seed step; add gitignore; remove per-file cp calls |
| `ai-agent.sh` | Bind mount; remove named volume, host config mounts, sync subcommand |
| `ai-agent.ps1` | Same |

## Behaviour Summary

| Scenario | Outcome |
|----------|---------|
| New workspace (empty `.agent/`) | Seeded from golden image: plugins, config, all files |
| Existing workspace | Seed skips existing files; workspace config is authoritative |
| Second project directory | Gets its own `.agent/` seeded fresh from golden image |
| Credentials | Always injected from host `~/.claude/.credentials.json` |
| Image rebuild | New files added to image seed propagate to existing workspaces on next start |
| Config change in `claude-config/` | Takes effect in new workspaces; existing workspaces unaffected |

## Out of Scope

- Migration of history from the old `ai-agent-claude` global volume
- Host mode (`--install`) — unaffected
