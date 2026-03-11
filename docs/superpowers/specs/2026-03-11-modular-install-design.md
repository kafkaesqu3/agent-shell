# Modular Install Design

**Date:** 2026-03-11
**Status:** Approved

## Overview

Refactor `install.sh` into a modular dispatcher backed by focused sub-scripts.
Merge `claude-config/setup.sh` (OS-aware dev tools) into `install/tools.sh`.
Add `install/mcp.sh` as a dedicated MCP server installer.
Support both flag-based and interactive-menu invocation.

## File Structure

```
agent-shell/
├── install.sh              # dispatcher (~70 lines): flags, menu, source + call modules
├── install/
│   ├── common.sh           # colors, log/ok/warn/err, cmd_exists, detect_os, shared vars
│   ├── config.sh           # install_config(): CLAUDE.md, settings.json, hooks, statusline
│   ├── tools.sh            # install_tools(): nvm/node/claude + OS dev tools (merged setup.sh)
│   ├── mcp.sh              # install_mcp(): npm MCP servers + mcp-server-fetch venv
│   ├── docker.sh           # install_docker(): build ai-agent:latest + optional browsing
│   └── path.sh             # install_path(): symlinks, claude wrapper, shell snippets
└── claude-config/
    └── setup.sh            # DELETED — logic merged into install/tools.sh
```

Each module:
- Defines a single public function (`install_<name>()`)
- Is sourceable by `install.sh` for normal use
- Is independently runnable via `if [[ "${BASH_SOURCE[0]}" == "${0}" ]]` guard

## CLI Interface

```
./install.sh [OPTIONS]

  (no flags)      Interactive menu
  --all           Run all steps: config + tools + mcp + docker + path
  --config        Install Claude Code config files
  --tools         Install nvm/node/claude + OS dev tools
  --mcp           Install MCP servers
  --docker        Build Docker images
  --path          Set up symlinks, claude wrapper, shell snippets
  --skip-docker   When used with --all, skip Docker build
  -h, --help      Show help
```

Flags are combinable: `./install.sh --config --mcp`

## Interactive Menu

Shown when `install.sh` is invoked with no arguments:

```
What would you like to install?

  1) All (config + tools + MCP + path)
  2) Claude Code config (CLAUDE.md, settings, hooks)
  3) Tools (nvm, Node.js, Claude Code, dev tools)
  4) MCP servers
  5) Docker images
  6) PATH + shell aliases
  q) Quit

Select (1-6, q):
```

Multi-select supported: enter `2 3 4` to run those steps in order.

## Module Responsibilities

### install/common.sh
- Color variables, `info`/`ok`/`warn`/`err` helpers
- `cmd_exists()` — checks if a command is on PATH
- `detect_os()` — returns `macos | ubuntu | fedora | arch | linux | unknown`
- Shared constants: `CLAUDE_HOME`, `CONFIG_DIR`, `SCRIPT_DIR`, `LOCAL_BIN`
- Sourced only; not independently runnable

### install/config.sh → `install_config()`
- Merges `settings.json` via jq (repo as base, host mcpServers win on re-run)
- Installs/replaces `CLAUDE.md` (marker-based idempotency check)
- Copies `statusline.sh`, `skill-profiles.json`, hook scripts to `~/.claude/`

### install/tools.sh → `install_tools()`
- nvm install/activate, Node.js 22, Claude Code (official curl installer)
- OS-aware system packages via `install_macos/ubuntu/fedora/arch()`
  (merged from `claude-config/setup.sh`)
- `install_cargo_tools()` — git-wt, cargo-audit, cargo-deny
- `install_python_tools()` — ruff, pytest, pip-audit via uv or pip3

### install/mcp.sh → `install_mcp()`
- npm globals: `@modelcontextprotocol/server-filesystem`, `server-github`,
  `mcp-server-sqlite-npx`, `brave-search-mcp`, `server-sequential-thinking`,
  `@upstash/context7-mcp`, `server-puppeteer`, `@playwright/mcp`
- `mcp-server-fetch` in isolated Python venv → symlinked to `~/.local/bin`

### install/docker.sh → `install_docker()`
- Validates Docker daemon is running
- Builds `ai-agent:latest` (base target)
- Interactive prompt for optional `ai-agent-browsing:latest` (Chromium)

### install/path.sh → `install_path()`
- Symlinks `ai-agent.sh` → `~/.local/bin/ai-agent`
- Installs `claude-wrapper.sh` as `claude`, renames real binary to `claude-host`
- Adds `~/.local/bin` to PATH in shell rc if missing
- Copies `.env.example` → `~/.config/ai-agent/.env` if none exists
- Prints shell snippets for manual addition (zsh/bash function + PowerShell function)

### install.sh (dispatcher)
- Sources `install/common.sh` unconditionally
- Sources and calls only the requested modules
- Execution order when multiple steps selected: config → tools → mcp → docker → path
- Default (`--all`): config + tools + mcp + path (docker skipped unless `--docker` or `--all` without `--skip-docker`)

## Migration Notes

- `claude-config/setup.sh` is deleted; its `detect_os`, OS install functions,
  `install_cargo_tools`, and `install_python_tools` move verbatim into
  `install/tools.sh` and `install/common.sh`
- Existing flags (`--config-only`, `--path-only`, `--docker-only`, `--no-tools`,
  `--no-path`) are replaced by the new combinable flag set
- `--all --skip-docker` replaces the old default behavior (no Docker)
