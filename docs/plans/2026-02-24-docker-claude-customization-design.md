# Enhanced AI Agent Docker Container — Claude Code Customization

**Date:** 2026-02-24
**Goal:** Personal power-user setup with baked-in Claude Code configuration, MCP servers, and layered config overrides.

## Architecture

Single Dockerfile with multi-stage build + `ENABLE_BROWSING` build arg (default: `false`).

- Stage 1 (base): All AI tools + Claude Code customizations + lightweight MCP servers
- Stage 2 (browsing): Adds chromium, playwright, puppeteer on top of base

Entrypoint script handles config layering at runtime.

## Config Layering

```
[Baked defaults] → [Host mounts override] → [Entrypoint merges env vars]
```

1. **CLAUDE.md**: Baked copy of user's current CLAUDE.md. Entrypoint checks for host mount at `/root/.claude/CLAUDE.md.host` — uses it if present, otherwise falls back to baked version.
2. **settings.json**: Baked with MCP server definitions + sensible defaults. Host mount overrides if present.
3. **MCP config**: Lives in baked `settings.json` under `mcpServers`. Entrypoint patches env vars (API keys) from container environment at startup.
4. **Credentials**: Persistent Docker volume for `/root/.claude`. Host mount takes priority if provided.

## MCP Servers

| Server | Package | Variant |
|--------|---------|---------|
| Fetch | `@modelcontextprotocol/server-fetch` | base |
| Filesystem | `@modelcontextprotocol/server-filesystem` | base |
| GitHub | `@modelcontextprotocol/server-github` | base |
| SQLite | `@modelcontextprotocol/server-sqlite` | base |
| Context7 | `@upstash/context7-mcp` | base |
| Sequential Thinking | `@modelcontextprotocol/server-sequential-thinking` | base |
| Brave Search | `@modelcontextprotocol/server-brave-search` | base |
| Puppeteer | `@modelcontextprotocol/server-puppeteer` | browsing |
| Playwright | `@playwright/mcp` | browsing |

## Entrypoint Script (`entrypoint.sh`)

1. If `/root/.claude/CLAUDE.md.host` exists → copy to `/root/.claude/CLAUDE.md`
2. Patch `settings.json` MCP env vars from container env (`BRAVE_API_KEY`, `GITHUB_TOKEN`, etc.)
3. If `CLAUDE_CODE_OAUTH_TOKEN` set and no credentials file → write credentials
4. Exec into requested command

## Docker Compose

```yaml
services:
  ai-agent:
    build:
      context: .
      args:
        ENABLE_BROWSING: "true"
    volumes:
      - .:/workspace
      - ai-agent-claude:/root/.claude
      - ~/.claude/CLAUDE.md:/root/.claude/CLAUDE.md.host:ro  # optional
      - ~/.gitconfig:/root/.gitconfig:ro
    env_file:
      - .env
```

## Launcher Script Changes

Both `ai-agent.sh` and `ai-agent.ps1`:
- Mount `~/.claude/CLAUDE.md` as `.host` if it exists
- Use named volume for `/root/.claude` persistence
- Pass through all env vars from `.env`

## File Structure

```
agent-shell/
├── Dockerfile                 # Single multi-stage Dockerfile
├── docker-compose.yml         # Updated
├── entrypoint.sh              # NEW: Config layering
├── claude-config/
│   ├── CLAUDE.md              # Baked default CLAUDE.md
│   └── settings.json          # Baked settings + MCP servers
├── ai-agent.sh                # Updated launcher
├── ai-agent.ps1               # Updated launcher
├── browsing/Dockerfile        # Deprecated (kept for reference)
├── MORE.md
└── README.md
```
