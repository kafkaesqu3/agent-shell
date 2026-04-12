# Workspace-Local Claude Storage

**Date:** 2026-04-11
**Status:** Approved (revised)

## Problem

The global named Docker volume `ai-agent-claude` is shared across every container from every
project. Conversation history from one workspace is visible when working in another. This is a
security concern and makes it impossible to reason about what context a session has access to.

## Goal

Scope all Claude data to the workspace the container was launched from. Conversation history,
memories, and per-project state must be accessible as plain files in the workspace. Sensitive
files (credentials, session tokens) must never touch the workspace filesystem.

## Design

### Volume Strategy

Replace the single global named volume with two mounts per container:

| Mount | Type | Source | Container path |
|-------|------|--------|----------------|
| Per-project state | Named volume | `ai-agent-claude-<container-name>` | `/home/agent/.claude/` |
| Conversation history | Bind mount | `$(pwd)/.agent/` (host) | `/home/agent/.claude/projects/` |

The bind mount at `projects/` overlaps and shadows the named volume at that subpath. Docker
processes mounts in order; the bind mount takes precedence for `/home/agent/.claude/projects/`.

The old global `ai-agent-claude` named volume is retired. Each workspace gets its own
`ai-agent-claude-<name>` volume, where `<name>` is the container name (which defaults to the
workspace directory name).

### What Is Visible in the Workspace

| Data | Location on host | Accessible in `.agent/`? |
|------|-----------------|--------------------------|
| Conversation history | `$(pwd)/.agent/projects/` | Yes |
| Memories (auto-memory files) | `$(pwd)/.agent/projects/<workspace>/memory/` | Yes |
| MCP config | `claude-config/mcp-servers.json` (repo) | Yes (source of truth is the repo) |
| Hook scripts | `claude-config/hooks/` (repo) | Yes (source of truth is the repo) |
| Credentials | Named volume only | No — never in workspace |
| `claude.json` session state | Named volume only | No — never in workspace |

No `.gitignore` is needed: sensitive files are in the named volume and never written to the
workspace bind mount.

### `claude.json` Handling

Unchanged. The entrypoint's copy-in/copy-out pattern continues to work against the per-project
named volume. No entrypoint changes are required.

### Launcher Changes (`ai-agent.sh` and `ai-agent.ps1`)

1. Remove the `VOLUME_NAME="ai-agent-claude"` constant
2. Derive a per-project volume name before building docker args:
   `ai-agent-claude-${CONTAINER_NAME:-$(basename "$(pwd)")}` (bash)
3. Replace the single volume mount with two mounts:
   - `-v "ai-agent-claude-<name>:/home/agent/.claude"`
   - `-v "$(pwd)/.agent:/home/agent/.claude/projects"`
4. Create `$(pwd)/.agent/` before `docker run` so it is host-user-owned
5. Remove the `sync` subcommand — it existed solely to copy `projects/` out of the container;
   with the bind mount, history is already written directly to the workspace

### Entrypoint Changes

None. All existing logic (config copy-in from image, credentials injection, `claude.json`
copy-in/copy-out, MCP setup, skill profiles) continues to work unchanged against the
per-project named volume.

## Files Changed

| File | Change |
|------|--------|
| `ai-agent.sh` | Per-project volume + projects bind mount; remove `sync`; add `mkdir -p .agent` |
| `ai-agent.ps1` | Same |
| `entrypoint.sh` | No changes |

## Out of Scope

- Host mode (`--host`) — does not use Docker volumes; unaffected
- Migration of history from the old `ai-agent-claude` global volume — users who want to
  preserve old history can `docker cp` manually
