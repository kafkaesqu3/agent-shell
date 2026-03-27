# MCP Servers → claude.json Registration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Populate `~/.claude.json` `mcpServers` from `settings.json` on every container start so MCP servers are visible to Claude Code.

**Architecture:** Add a single jq transformation step near the end of `entrypoint.sh`, after all `settings.json` modifications are complete (placeholder substitution, browser MCP stripping). Converts stdio/SSE entries to the `claude.json` format, drops unresolved placeholders, then writes `mcpServers` into `~/.claude.json`.

**Tech Stack:** bash, jq (already present in image)

---

### Task 1: Add MCP registration step to entrypoint.sh

**Files:**
- Modify: `entrypoint.sh:177` (after browser MCP stripping block, before ownership fix)

- [ ] **Step 1: Add the mcpServers population block**

Insert the following block into `entrypoint.sh` after the browser MCP stripping section
(after line 177 — the `fi` closing the chromium check) and before the ownership fix comment:

```bash
# --- Populate ~/.claude.json mcpServers from settings.json ---
# Claude Code reads MCP servers from ~/.claude.json, not settings.json.
# Transform the now-final mcpServers block: add required type fields,
# add env:{} for stdio servers, drop entries with unresolved placeholders.
if [ -f /home/agent/.claude/settings.json ]; then
  MCP_SERVERS=$(jq '
    .mcpServers // {} |
    to_entries |
    map(select(
      (.value | tostring | test("__[A-Z_]+__") | not)
    )) |
    map(
      if .value | has("url") then
        .value += {"type": "sse"}
      else
        .value += {"type": "stdio"} | .value.env //= {}
      end
    ) |
    from_entries
  ' /home/agent/.claude/settings.json)
  tmp=$(mktemp)
  jq --argjson mcp "$MCP_SERVERS" '.mcpServers = $mcp' "$CLAUDE_JSON" > "$tmp" \
    && mv "$tmp" "$CLAUDE_JSON"
  chown agent:agent "$CLAUDE_JSON"
fi
```

- [ ] **Step 2: Verify the jq logic manually**

Run this test against the baked settings.json format (no container needed):

```bash
# Simulate with BRIGHTDATA_API_KEY unset (placeholder should be dropped)
jq '
  .mcpServers // {} |
  to_entries |
  map(select(
    (.value | tostring | test("__[A-Z_]+__") | not)
  )) |
  map(
    if .value | has("url") then
      .value += {"type": "sse"}
    else
      .value += {"type": "stdio"} | .value.env //= {}
    end
  ) |
  from_entries
' claude-config/settings.json
```

Expected: all stdio servers appear with `"type": "stdio"` and `"env": {}`;
`brightdata` entry is **absent** (because `__BRIGHTDATA_API_KEY__` is unresolved).

```bash
# Simulate with key substituted (brightdata should appear)
sed 's/__BRIGHTDATA_API_KEY__/testkey123/g' claude-config/settings.json | jq '
  .mcpServers // {} |
  to_entries |
  map(select(
    (.value | tostring | test("__[A-Z_]+__") | not)
  )) |
  map(
    if .value | has("url") then
      .value += {"type": "sse"}
    else
      .value += {"type": "stdio"} | .value.env //= {}
    end
  ) |
  from_entries
'
```

Expected: brightdata appears with `"type": "sse"` and no `env` field.

- [ ] **Step 3: Commit**

```bash
git add entrypoint.sh
git commit -m "fix: populate claude.json mcpServers from settings.json on start"
```
