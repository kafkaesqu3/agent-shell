# Agent Configurations Design

**Date:** 2026-03-11
**Status:** Approved

## Overview

Add cross-project Claude Code agent definitions to the agent-shell config system. Agents are markdown files with YAML frontmatter installed to `~/.claude/agents/` via a new `install/agents.sh` module.

## Goals

- Define 8 reusable agent roles covering research, development, infrastructure, code review, security, and offensive security
- Integrate with the existing `claude-config/` source-of-truth pattern
- Add `--agents` flag and menu option to `install.sh`
- Preserve local customizations on re-runs (skip-if-exists, not overwrite)

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

install.sh   (updated: --agents flag, menu option 7, --all includes agents)
```

## Agent Definitions

Each file: YAML frontmatter (`name`, `description`, `tools`) + system prompt body.

### research
- **Tools:** `WebSearch, WebFetch, Read, Glob, Grep`
- **Role:** Web research, synthesis, summarization. No file modification.
- **Anti-cases:** Writing code, modifying files.

### developer
- **Tools:** All
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

## Install Logic

`install/agents.sh` — `install_agents()` function:

```
for each .md in claude-config/agents/:
  if ~/.claude/agents/<name>.md exists:
    skip (log "already exists — local copy preserved")
  else:
    copy to ~/.claude/agents/<name>.md
    log "installed"
```

`install.sh` changes:
- `--agents` CLI flag
- Menu option 7 (agents only)
- `--all` expands to: config + tools + mcp + agents + path (no docker by default)
- `_usage()` updated

## Constraints

- No merge logic — skip-if-exists is sufficient. Users who want updates delete the local file and re-run.
- Agent files must use LF line endings (enforced by `.gitattributes`).
- System prompts are role-locked: each agent states what it is, what it focuses on, and explicitly what it does not do.
- Offensive agents (pentester, vulnerability-researcher) assert authorization context in their system prompts before acting.
