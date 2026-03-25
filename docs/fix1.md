# Fix: MCP Servers Not Appearing in Container

## Root Cause: MCP servers are configured in the wrong file

Claude Code reads user-scope MCP servers from **`~/.claude.json`** (populated by
`claude mcp add --scope user`), **not** from `~/.claude/settings.json`.

All MCP server definitions in `claude-config/settings.json` under `mcpServers` are
written to `settings.json` inside the container — but Claude Code ignores them there.
That is why `claude mcp get brave-search` returns "No MCP server found" even though
the config looks correct.

Confirmed by running `claude mcp add --scope user` inside the container: it writes to
`/home/agent/.claude.json`, not to `/home/agent/.claude/settings.json`. After adding
brave-search to `claude.json`, it immediately appeared in `claude mcp list`.

## Why only context7 works

The `context7` MCP server appears because it is provided by the **plugin**
(`context7@claude-plugins-official`), not by `settings.json`. Plugins register their
own servers through a different mechanism that does not depend on `mcpServers` in
settings.json.

## Secondary issues (also present)

**1. `type: "sse"` in brightdata entry**

The currently-baked image has the brightdata entry as:
```json
"brightdata": {
  "type": "sse",
  "url": "https://mcp.brightdata.com/sse?token=__BRIGHTDATA_API_KEY__"
}
```
The `type` field is not part of the settings.json format and caused Claude Code to
reject the entry silently. The correct format is just `"url"` with no `type`:
```json
"brightdata": {
  "url": "https://mcp.brightdata.com/sse?token=__BRIGHTDATA_API_KEY__"
}
```
The source file (`claude-config/settings.json`) has already been fixed but the image
has not been rebuilt since.

**2. `NPM_CONFIG_IGNORE_SCRIPTS=true` persists at runtime**

The Dockerfile sets this as a Docker `ENV` for build-time supply-chain hardening.
Docker `ENV` is baked into the image and present in every shell, including `docker exec`
sessions. The `unset` added to `entrypoint.sh` only helps the initial container session
started by the entrypoint — it does not affect shells opened via `docker exec`.

This caused `@brightdata/mcp` to install with a broken npm cache on first use (the
`mdast-util-to-markdown` dependency was missing because its postinstall script was
suppressed). This issue is now moot since brightdata is switching to SSE transport, but
the env var still affects any future npx-based MCP server that is not pre-installed in
the image.

## The fix required

`entrypoint.sh` needs a new step that:

1. Reads the `mcpServers` block from `settings.json` after placeholder substitution
2. Normalises the format to what `claude.json` requires (adds explicit `"type": "stdio"`
   or `"type": "sse"` fields, adds empty `"env": {}` for stdio servers)
3. Drops any entries that still contain unresolved `__PLACEHOLDER__` values (i.e. the
   corresponding API key was not provided)
4. Writes the result into `~/.claude.json` under the `mcpServers` key on every
   container start

After this change the image must be rebuilt so the corrected `settings.json`
(without `type: "sse"`) is baked in.
