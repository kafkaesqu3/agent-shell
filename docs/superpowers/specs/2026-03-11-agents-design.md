# Agent Configurations Design

**Date:** 2026-03-11
**Status:** Approved

## Overview

Add cross-project Claude Code agent definitions to the agent-shell config system. Agents are markdown files with YAML frontmatter installed to `~/.claude/agents/` via a new `install/agents.sh` module.

## Goals

- Define 8 reusable agent roles covering research, development, infrastructure, code review, security, and offensive security
- Integrate with the existing `claude-config/` source-of-truth pattern
- Add `--agents` flag and menu option to `install.sh`
- Preserve local customizations on re-runs (skip-if-exists on the host path)
- Mirror agents into Docker containers via `entrypoint.sh` (overwrite-always, consistent with all other config files in the container)

## Prerequisites

Agents require `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` to be active. This is already set in `claude-config/settings.json`. Users who run `--agents` without `--config` should be warned that this env var must be present in their `~/.claude/settings.json`.

## File Layout

```
claude-config/
└── agents/
    ├── research.md
    ├── developer.md
    ├── infrastructure.md
    ├── code-reviewer.md
    ├── security-engineer.md
    ├── reverse-engineer.md
    ├── vulnerability-researcher.md
    └── pentester.md

install/
└── agents.sh

install.sh   (updated: --agents flag, menu option 7, --all includes agents, _run() refactored)
entrypoint.sh (updated: agents copy block)
```

## Agent Definitions

Each file: YAML frontmatter (`name`, `description`, `tools`) + system prompt body.

The `tools` frontmatter value must use exact Claude Code tool names. For the `developer` agent, omit the `tools` key entirely — this defaults to all tools. All other agents specify an explicit comma-separated list.

### research
- **Tools:** `WebSearch, WebFetch, Read, Glob, Grep`
- **Role:** Web research, synthesis, summarization. No file modification.
- **Anti-cases:** Writing code, modifying files.

### developer
- **Tools:** (omit — defaults to all tools)
- **Role:** Full implementation — features, bugfixes, refactors. Follows project coding standards.
- **Anti-cases:** Pure research with no code changes.

### infrastructure
- **Tools:** `Bash, Read, Write, Edit, Glob, Grep`
- **Role:** Docker, Terraform, SSH, system administration. Local infra only — no web access.
- **Anti-cases:** Application code development.

### code-reviewer
- **Tools:** `Read, Glob, Grep`
- **Role:** Read-only code review. Identifies issues, suggests improvements, never edits.
- **Anti-cases:** Implementing fixes (use developer for that).

### security-engineer
- **Tools:** `Read, Glob, Grep, WebSearch, WebFetch, Bash`
- **Role:** Defensive security — threat modeling, OWASP review, secure coding, hardening.
- **Anti-cases:** Active exploitation (use pentester/vulnerability-researcher).

### reverse-engineer
- **Tools:** `Bash, Read, Glob, Grep`
- **Role:** Binary analysis, disassembly, protocol reverse engineering, malware analysis.
- **Anti-cases:** Web research (no WebSearch/WebFetch).

### vulnerability-researcher
- **Tools:** `Read, Glob, Grep, Bash, WebSearch, WebFetch`
- **Role:** CVE research, vulnerability discovery, responsible disclosure documentation.
- **Anti-cases:** Active exploitation of live systems (use pentester).

### pentester
- **Tools:** `Bash, Read, Write, Glob, Grep, WebSearch, WebFetch`
- **Role:** Active penetration testing in authorized engagements (CTF, red team, contracted pentest). Write access for payloads and notes. Follows recon → enum → exploit → post-exploit → report methodology.
- **Anti-cases:** Any unauthorized or production systems.

## install/agents.sh

```bash
#!/usr/bin/env bash
set -euo pipefail
[[ -z "${SCRIPT_DIR:-}" ]] && source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/install/common.sh"

install_agents() {
  echo -e "${BOLD}--- Installing Claude Code Agents ---${NC}"

  local src="$SCRIPT_DIR/claude-config/agents"
  local dst="$CLAUDE_HOME/agents"

  if [[ ! -d "$src" ]]; then
    warn "claude-config/agents/ not found — skipping"
    return
  fi

  if ! grep -q 'CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS' "$CLAUDE_HOME/settings.json" 2>/dev/null; then
    warn "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS not found in settings.json — run --config first or agents may not work"
  fi

  mkdir -p "$dst"

  shopt -s nullglob
  local agent_files=("$src"/*.md)
  shopt -u nullglob

  if [[ ${#agent_files[@]} -eq 0 ]]; then
    warn "No agent files found in $src"
    return
  fi

  for src_file in "${agent_files[@]}"; do
    local name
    name=$(basename "$src_file")
    local dst_file="$dst/$name"

    if [[ -f "$dst_file" ]]; then
      ok "  $name already exists — skipping (local copy preserved)"
    else
      cp "$src_file" "$dst_file"
      ok "  $name installed"
    fi
  done

  echo ""
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/install/common.sh"
  install_agents
fi
```

## install.sh Changes

### `_run()` refactor

The current `_run()` takes 5 positional parameters which hits the ≤5 limit from coding standards. Adding `do_agents` would push it to 6. Refactor `_run()` to read the `do_*` variables from the enclosing scope (already set as locals in `_menu()` and globals in the flag-parsing block) rather than accepting positional params:

```bash
_run() {
  [[ "$do_config" == true ]] && { source "$SCRIPT_DIR/install/config.sh"; install_config; }
  [[ "$do_tools"  == true ]] && { source "$SCRIPT_DIR/install/tools.sh";  install_tools;  }
  [[ "$do_mcp"    == true ]] && { source "$SCRIPT_DIR/install/mcp.sh";    install_mcp;    }
  [[ "$do_agents" == true ]] && { source "$SCRIPT_DIR/install/agents.sh"; install_agents; }
  [[ "$do_docker" == true ]] && { source "$SCRIPT_DIR/install/docker.sh"; install_docker; }
  [[ "$do_path"   == true ]] && { source "$SCRIPT_DIR/install/path.sh";   install_path;   }
}
```

All call sites (`_menu`, flag-parsing block) add `do_agents` to their variable declarations and set it appropriately.

### Menu and flags

- Menu option 7: `"7) Claude Code agents"`, prompt updated to `"Select (1-7, q, or multiple e.g. '2 3')"`
- `--agents` flag sets `do_agents=true`
- `--all` sets `do_agents=true` (alongside existing config/tools/mcp/path)
- `_usage()` gains `--agents  Install Claude Code agent definitions` line

### `--all` semantics — no change

`--all` already excludes Docker by default (requires `--skip-docker` to suppress, or Docker is added when `skip_docker == false`). This behaviour is unchanged.

## entrypoint.sh Changes

Add agents copy block after the existing hooks block (line ~53), using overwrite-always semantics consistent with all other config files in the container:

```bash
# --- Copy agent definitions ---
if [ -d /opt/claude-config/agents ]; then
  mkdir -p /home/agent/.claude/agents
  cp /opt/claude-config/agents/*.md /home/agent/.claude/agents/
fi
```

The `COPY claude-config/ /opt/claude-config/` in the Dockerfile already covers the new `agents/` subdirectory — no Dockerfile change needed.
