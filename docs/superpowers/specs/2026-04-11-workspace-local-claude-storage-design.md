# Workspace-Local Claude Storage

**Date:** 2026-04-11
**Status:** Approved

## Problem

The global named Docker volume `ai-agent-claude` is shared across every container from every
project. Conversation history from one workspace is visible when working in another. This is a
security concern and makes it impossible to reason about what context a session has access to.

## Goal

Scope all Claude data (conversation history, session state, config copies) to the workspace the
container was launched from. Sensitive files must never be committable to git accidentally.

## Design

### Volume Strategy

Replace the global named volume with a per-workspace bind mount:

```
$(pwd)/.agent/   →   /home/agent/.claude/   (inside container)
```

- Every project gets its own isolated `.agent/` directory.
- No cross-project history bleed.
- All Claude data is scoped to that workspace: history, config copies, session state.
- The bind mount is workspace-local, so logs are accessible as plain files on the host.

The global `ai-agent-claude` named volume is retired entirely.

### Gitignore Protection

`entrypoint.sh` writes `/home/agent/.claude/.gitignore` (i.e. `$(pwd)/.agent/.gitignore` on the
host) **if the file does not already exist**, so users can customize it. This runs on every
container startup as the first write into the directory.

Default `.gitignore` content:

```gitignore
# Sensitive credentials — never commit
.credentials.json
claude.json

# Config derived from Docker image — source of truth is claude-config/ in the repo
settings.json
CLAUDE.md
CLAUDE.*.md
commands/
hooks/
agents/
statusline.sh
.zshrc

# Large downloaded caches — not useful to commit
plugins/
statsig/
```

`projects/` and `todos/` are intentionally left unignored — that is the conversation history
the user wants accessible. Users can add them to the `.gitignore` manually if they do not
want history tracked in git.

### `claude.json` Handling

Claude Code writes session state to `~/.claude.json` (adjacent to `~/.claude/`, not inside it).
The entrypoint's existing copy-in/copy-out pattern is unchanged:

- **Startup:** copy `~/.claude/claude.json` (from bind mount = workspace) → `~/.claude.json`
- **Exit trap:** copy `~/.claude.json` → `~/.claude/claude.json` (back into bind mount = workspace)

The only change is that the backing store is now `$(pwd)/.agent/claude.json` instead of the
global named volume. `claude.json` is covered by the auto-written `.gitignore`.

### Launcher Changes (`ai-agent.sh` and `ai-agent.ps1`)

1. Remove `-v "ai-agent-claude:/home/agent/.claude"`
2. Add `-v "$(pwd)/.agent:/home/agent/.claude"` (bash) / `"${CurrentDir}/.agent:/home/agent/.claude"` (PS1)
3. Create `$(pwd)/.agent/` before `docker run` so Docker does not create it root-owned

The `sync` subcommand is removed. It existed solely to copy logs out of the container into the
host's `~/.claude/projects/`. With the bind mount design, logs are already written directly to
the workspace — no sync step is needed.

### Entrypoint Changes (`entrypoint.sh`)

1. Write `.gitignore` into `/home/agent/.claude/` if it does not exist (new, runs first)
2. No other changes — the `CLAUDE_JSON_STORE` copy-in/copy-out logic continues to work
   unchanged; it now reads/writes `$(pwd)/.agent/claude.json` via the bind mount

### What Persists vs. What Is Ephemeral

| Data | Location | Persists across restarts? |
|------|----------|--------------------------|
| Conversation history | `$(pwd)/.agent/projects/` | Yes — bind-mounted to workspace |
| Todos | `$(pwd)/.agent/todos/` | Yes — bind-mounted to workspace |
| `claude.json` session state | `$(pwd)/.agent/claude.json` | Yes — via copy-out on exit |
| Credentials | from host `~/.claude/.credentials.json` | Yes — re-injected each run |
| Config (settings, CLAUDE.md, hooks…) | baked into image | Yes — reset from image each run |
| Plugin cache | `$(pwd)/.agent/plugins/` | Yes — bind-mounted to workspace |
| Statsig cache | `$(pwd)/.agent/statsig/` | Yes — bind-mounted to workspace |

Everything that was previously in the global named volume is now either workspace-local or
re-derived at startup. No data that matters is lost.

## Files Changed

| File | Change |
|------|--------|
| `ai-agent.sh` | Replace named volume with workspace bind mount; remove `sync` subcommand |
| `ai-agent.ps1` | Same as above |
| `entrypoint.sh` | Write auto-`.gitignore` on startup if not present |

## Out of Scope

- Host mode (`--host`) — does not use Docker volumes; unaffected
- The `--rm` ephemeral flag — bind mounts persist on host even when container is removed; behaviour improves (history survives `--rm` sessions)
