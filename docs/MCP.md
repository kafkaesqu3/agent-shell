# MCP Server Configuration

## How Claude Code reads MCP servers

Claude Code does **not** read MCP servers from `settings.json`. It reads them from:

| Scope | File | Notes |
|---|---|---|
| **User** | `~/.claude.json` (`mcpServers` key) | Available across all projects |
| **Project** | `.mcp.json` in project root | Checked into git; requires per-project approval |
| **Managed** | `/etc/claude-code/managed-mcp.json` | System-level exclusive control (blocks project `.mcp.json`) |

This repo uses **user scope** (`~/.claude.json`) for the shared server set so that project-level `.mcp.json` files in `/workspace` continue to work alongside them.

> **Known Claude Code behaviour:** The top-level `mcpServers` key in `~/.claude.json` is the correct user-scope location, but if any project entry (`projects["<path>"].mcpServers`) exists with an empty `{}` value it silently shadows the global servers for that path. Tracked in [#35144](https://github.com/anthropics/claude-code/issues/35144), [#16728](https://github.com/anthropics/claude-code/issues/16728), [#32939](https://github.com/anthropics/claude-code/issues/32939). The entrypoint works around this by removing empty `mcpServers` from all project entries each startup so the global servers are never shadowed. Each server entry must also include a `"type"` field (`"stdio"` for command-based, `"http"` for URL-based) — Claude Code's schema validator rejects entries without it.

## Source of truth

**`claude-config/mcp-servers.json`** defines all MCP servers in the native `.mcp.json` format:

```json
{
  "mcpServers": {
    "name": { "command": "...", "args": [...] },
    "sse-server": { "url": "https://..." }
  }
}
```

Both the Docker and host install paths read this file and write the `mcpServers` key into `~/.claude.json`.

Placeholders (e.g. `__BRIGHTDATA_API_KEY__`) are substituted from environment variables at apply time. Any entry that still contains an unresolved placeholder is silently dropped.

## Docker

`mcp-servers.json` is **not** baked into the `lite` image — that image has no MCP packages installed.

| Image | `mcp-servers.json` baked? | Browser servers? |
|---|---|---|
| `lite` | No | No |
| `base` | Yes (all non-browser servers) | No |
| `browsing` | Yes (base + puppeteer + playwright) | Yes |

The `browsing` stage patches the baked file at build time to add the browser entries:

```dockerfile
RUN jq '.mcpServers += {
      "puppeteer": {"command": "npx", "args": ["-y", "@modelcontextprotocol/server-puppeteer"]},
      "playwright": {"command": "npx", "args": ["-y", "@playwright/mcp", "--headless"]}
    }' /opt/claude-config/mcp-servers.json > /tmp/mcp-servers.json \
    && mv /tmp/mcp-servers.json /opt/claude-config/mcp-servers.json
```

On every container start, `entrypoint.sh` reads the baked `mcp-servers.json`, substitutes placeholders, drops unresolved entries, and merges the result into `~/.claude.json`.

## Host install (`install.sh`)

Running `install.sh --mcp` (or `--all`) does two things:

1. Installs MCP npm packages globally and `mcp-server-fetch` into a Python venv
2. Reads `claude-config/mcp-servers.json`, substitutes env vars, and merges the servers into `~/.claude.json`

If `BRIGHTDATA_API_KEY` is set in the environment (or loaded from `.env`), the brightdata SSE server is registered. Otherwise it is skipped.

## Adding a new MCP server

1. Add the entry to `claude-config/mcp-servers.json`
2. If it requires an npm package, add it to the `RUN npm install -g` block in the `base` stage of the Dockerfile and to `install/mcp.sh`
3. Rebuild the Docker image (`install.sh --docker`) or re-run `install.sh --mcp` on the host
4. If the server is browser-only, add it to the `browsing` stage jq patch instead of `mcp-servers.json`

## Adding a project-specific MCP server

Create a `.mcp.json` file at the root of the project (in `/workspace`). Claude Code will load it alongside the user-scope servers from `~/.claude.json`. No changes to this repo are needed.

```json
{
  "mcpServers": {
    "my-server": {
      "command": "npx",
      "args": ["-y", "my-mcp-package"]
    }
  }
}
```
