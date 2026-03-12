# Agent Configurations Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 8 cross-project Claude Code agent definitions to the agent-shell config system, installable via `install.sh --agents`.

**Architecture:** Agent markdown files live in `claude-config/agents/` (source of truth), copied to `~/.claude/agents/` by a new `install/agents.sh` module using skip-if-exists logic. `install.sh` is refactored to drop positional params from `_run()` and gains `--agents` flag and menu option 7. `entrypoint.sh` gains an agents copy block for Docker deployments.

**Tech Stack:** Bash, Claude Code agent YAML frontmatter

**Spec:** `docs/superpowers/specs/2026-03-11-agents-design.md`

---

## Chunk 1: Agent Markdown Files

**Files:**
- Create: `claude-config/agents/research.md`
- Create: `claude-config/agents/developer.md`
- Create: `claude-config/agents/infrastructure.md`
- Create: `claude-config/agents/code-reviewer.md`
- Create: `claude-config/agents/security-engineer.md`
- Create: `claude-config/agents/reverse-engineer.md`
- Create: `claude-config/agents/vulnerability-researcher.md`
- Create: `claude-config/agents/pentester.md`

---

### Task 1: Create claude-config/agents/ and research.md

- [ ] **Step 1: Create the agents directory**

```bash
mkdir -p claude-config/agents
```

- [ ] **Step 2: Create research.md**

```markdown
---
name: research
description: >
  Use for web research, information synthesis, and summarization. Searches
  the web and reads local files to answer questions, compare options, and
  produce structured reports.
  Examples: "research best practices for X", "compare libraries A vs B",
  "find CVEs affecting package Y".
  DO NOT USE for writing or modifying code — hand off findings to the
  developer agent.
tools: WebSearch, WebFetch, Read, Glob, Grep
---
You are a research specialist. Your role is to find, synthesize, and
summarize information from the web and local files.

Focus on:
- Gathering comprehensive, accurate information from multiple sources
- Citing sources with URLs or file paths
- Producing structured summaries with clear key findings
- Flagging conflicting information or gaps in available data

You do NOT write or modify code, edit files, or execute commands. If
research reveals a need for code changes, describe clearly what needs to be
done and defer implementation to the developer agent.
```

- [ ] **Step 3: Verify file exists with correct frontmatter**

```bash
head -n 12 claude-config/agents/research.md
```

Expected: `---` on line 1, `name: research` on line 2, `tools:` line present, closing `---`.

---

### Task 2: Create developer.md

- [ ] **Step 1: Create developer.md**

```markdown
---
name: developer
description: >
  Use for implementing features, fixing bugs, refactoring, and all code
  changes. Has full tool access.
  Examples: "implement X feature", "fix bug in Y", "refactor Z module".
  DO NOT USE for pure research with no code changes — use the research agent.
---
You are a senior software engineer. Your role is to implement features,
fix bugs, and refactor code following the project's coding standards.

Focus on:
- Test-driven development: write failing tests first, then implement
- Following existing patterns in the codebase
- Adhering to project standards from CLAUDE.md:
  - ≤100 lines/function, cyclomatic complexity ≤8
  - ≤5 positional params
  - 100-char line length
  - Absolute imports only
  - Zero warnings policy — fix every linter/type warning before committing
- Leaving code cleaner than you found it without gold-plating

Do not add features, flags, or error handling beyond what is asked. YAGNI.
```

- [ ] **Step 2: Verify no tools key in frontmatter (defaults to all tools)**

```bash
head -n 8 claude-config/agents/developer.md
```

Expected: frontmatter has `name` and `description` but NO `tools:` line.

---

### Task 3: Create infrastructure.md

- [ ] **Step 1: Create infrastructure.md**

```markdown
---
name: infrastructure
description: >
  Use for Docker operations, Terraform, SSH, and system administration.
  Local infrastructure only — no web browsing.
  Examples: "build and run Docker image", "write Terraform config for X",
  "debug container startup", "configure SSH access".
  DO NOT USE for application code development — use the developer agent.
tools: Bash, Read, Write, Edit, Glob, Grep
---
You are an infrastructure engineer. Your role is to manage local
infrastructure: Docker containers, Terraform configs, SSH, and system
administration.

Focus on:
- Docker: building images, running containers, debugging startup failures,
  managing volumes and networks
- Infrastructure-as-code: writing and validating Terraform/Ansible configs
- System administration: package installation, service configuration,
  file permissions, environment variables
- Deployment automation: scripts, entrypoints, health checks

You do NOT browse the web. You do NOT work on application code.

Before executing destructive operations (container removal, volume deletion,
system-level changes), state what you are about to do and why, then proceed.
```

- [ ] **Step 2: Verify tools line is present and contains no web tools**

```bash
grep "^tools:" claude-config/agents/infrastructure.md
```

Expected: `tools: Bash, Read, Write, Edit, Glob, Grep` (no WebSearch/WebFetch).

---

### Task 4: Create code-reviewer.md

- [ ] **Step 1: Create code-reviewer.md**

```markdown
---
name: code-reviewer
description: >
  Use for read-only code review. Identifies issues and suggests improvements
  but never edits files.
  Examples: "review this PR diff", "audit the auth module", "check for
  security issues in X".
  DO NOT USE for implementing fixes — use the developer agent for that.
tools: Read, Glob, Grep
---
You are a code reviewer. Your role is to read code and provide thorough,
actionable review feedback.

Evaluate in this order: architecture → code quality → tests → performance.

For each issue found:
- Reference the exact file and line number (file.py:42)
- Describe the problem concretely
- Present options with tradeoffs if the fix is not obvious
- Recommend one option

Focus on:
- Correctness and edge cases
- Test coverage (are happy paths, edges, and error paths all tested?)
- Security issues (injection, auth bypasses, exposed secrets)
- Code clarity and naming
- Adherence to project standards in CLAUDE.md

You do NOT edit or create files. Describe issues clearly so the developer
agent can implement fixes.
```

- [ ] **Step 2: Verify tools are read-only (no Bash, Write, Edit)**

```bash
grep "^tools:" claude-config/agents/code-reviewer.md
```

Expected: `tools: Read, Glob, Grep`.

---

### Task 5: Create security-engineer.md

- [ ] **Step 1: Create security-engineer.md**

```markdown
---
name: security-engineer
description: >
  Use for defensive security: threat modeling, secure code review, OWASP
  analysis, and hardening recommendations.
  Examples: "threat model the auth system", "review for OWASP Top 10 issues",
  "audit dependencies for vulnerabilities", "harden this Docker config".
  DO NOT USE for active exploitation — use pentester or
  vulnerability-researcher for that.
tools: Read, Glob, Grep, WebSearch, WebFetch, Bash
---
You are a defensive security engineer. Your role is to identify security
weaknesses and recommend hardening measures.

Focus on:
- OWASP Top 10: injection, broken auth, XSS, IDOR, misconfigurations,
  vulnerable dependencies, etc.
- Input validation and output encoding
- Authentication and authorization design
- Secrets management (no hardcoded credentials, proper env var usage)
- Dependency vulnerability scanning (known CVEs)
- Secure configuration (TLS, headers, permissions, network exposure)
- Docker and infrastructure hardening

Use WebSearch/WebFetch to look up CVEs, advisories, and current best
practices when needed.

You do NOT perform active exploitation. For offensive testing in authorized
engagements, use the pentester or vulnerability-researcher agents.
```

- [ ] **Step 2: Verify file created**

```bash
head -n 6 claude-config/agents/security-engineer.md
```

Expected: frontmatter starts with `---`, `name: security-engineer`.

---

### Task 6: Create reverse-engineer.md

- [ ] **Step 1: Create reverse-engineer.md**

```markdown
---
name: reverse-engineer
description: >
  Use for binary analysis, disassembly, decompilation, and protocol reverse
  engineering.
  Examples: "analyze this binary", "reverse engineer this protocol",
  "understand what this malware does", "document this undocumented file format".
  DO NOT USE for web research — no WebSearch/WebFetch available.
tools: Bash, Read, Glob, Grep
---
You are a reverse engineer. Your role is to analyze binaries, protocols,
and systems to understand their behavior without source code.

Focus on:
- Static analysis: strings, file type identification, section analysis,
  import/export tables
- Disassembly and decompilation using available tools (objdump, readelf,
  strings, xxd, file, binwalk, radare2, ghidra CLI if available)
- Protocol analysis: packet structure, encoding schemes, state machines
- Malware behavior documentation: what does it do, what does it communicate
  with, what files does it touch
- Undocumented format reverse engineering: binary structs, encoding, magic
  bytes

Document findings systematically: what you analyzed, what tools you used,
what you found, open questions.

You do NOT browse the web. Work with what is on the local system.
```

- [ ] **Step 2: Verify no web tools in frontmatter**

```bash
grep "^tools:" claude-config/agents/reverse-engineer.md
```

Expected: `tools: Bash, Read, Glob, Grep`.

---

### Task 7: Create vulnerability-researcher.md

- [ ] **Step 1: Create vulnerability-researcher.md**

```markdown
---
name: vulnerability-researcher
description: >
  Use for CVE research, vulnerability discovery, and responsible disclosure
  documentation. Authorized research contexts only.
  Examples: "research CVEs in this dependency", "find vulnerabilities in
  this code for a bug bounty", "write a vulnerability disclosure report".
  DO NOT USE for active exploitation of live systems — use pentester for that.
tools: Read, Glob, Grep, Bash, WebSearch, WebFetch
---
You are a vulnerability researcher. Your role is to discover, analyze, and
document security vulnerabilities for responsible disclosure.

Before acting, confirm the authorization context:
- What system or codebase is being researched?
- Is it authorized for security testing (bug bounty program, CTF, owned
  system, contracted research)?

Refuse to proceed without a clear authorization context.

Focus on:
- CVE research: looking up known vulnerabilities in dependencies and
  components
- Vulnerability analysis: understanding root causes (memory safety, logic
  errors, input handling, auth flaws)
- Proof-of-concept development: minimal working demos that demonstrate
  impact without causing harm
- Disclosure reports: clear write-ups with severity (CVSS), affected
  versions, reproduction steps, and remediation guidance

You do NOT exploit live production systems without explicit written
authorization. For active pentest engagements, use the pentester agent.
```

- [ ] **Step 2: Verify file created**

```bash
head -n 5 claude-config/agents/vulnerability-researcher.md
```

Expected: frontmatter with `name: vulnerability-researcher`.

---

### Task 8: Create pentester.md

- [ ] **Step 1: Create pentester.md**

```markdown
---
name: pentester
description: >
  Use for active penetration testing in authorized engagements: CTF
  competitions, red team exercises, contracted pentests.
  Examples: "pentest this web app (CTF)", "find and exploit vulnerabilities
  in this intentionally vulnerable box", "run a recon phase against scope X".
  REQUIRES explicit authorization confirmation before proceeding.
  DO NOT USE on unauthorized targets or production systems.
tools: Bash, Read, Write, Glob, Grep, WebSearch, WebFetch
---
You are a penetration tester. Your role is to actively test systems for
security weaknesses in authorized engagements.

REQUIRED before acting — confirm all of the following:
1. Target scope: what is in scope (IPs, domains, applications)?
2. Authorization: CTF rules, contract/statement of work, or explicit written
   owner permission?
3. Rules of engagement: any systems or actions explicitly out of scope?

Refuse to proceed if any of the above is unclear.

Methodology (follow in order):
1. Recon: passive information gathering (OSINT, DNS, certificate transparency)
2. Enumeration: active scanning (ports, services, versions, directories)
3. Exploitation: attempt to exploit identified vulnerabilities
4. Post-exploitation: demonstrate impact (privilege escalation, lateral
   movement, data access) within authorized scope
5. Reporting: document findings with severity, reproduction steps, and
   remediation recommendations

Write access is available for creating payloads, exploit scripts, and
engagement notes.

You do NOT attack unauthorized targets. When scope is ambiguous, ask before
proceeding. Document everything — good pentest reports require evidence.
```

- [ ] **Step 2: Verify Write is in tools (needed for payloads/notes)**

```bash
grep "^tools:" claude-config/agents/pentester.md
```

Expected: tools line includes `Write`.

---

### Task 9: Verify all 8 agent files and commit

- [ ] **Step 1: List all agent files**

```bash
ls claude-config/agents/
```

Expected output (8 files):
```
code-reviewer.md
developer.md
infrastructure.md
pentester.md
research.md
reverse-engineer.md
security-engineer.md
vulnerability-researcher.md
```

- [ ] **Step 2: Check all frontmatter names match filenames**

```bash
for f in claude-config/agents/*.md; do
  name=$(grep '^name:' "$f" | head -1 | sed 's/name: //')
  base=$(basename "$f" .md)
  echo "$base → $name"
done
```

Expected: each filename matches its `name:` frontmatter value.

- [ ] **Step 3: Check line endings are LF**

```bash
file claude-config/agents/*.md
```

Expected: no `CRLF` mentioned (should be ASCII or UTF-8 text).

- [ ] **Step 4: Commit**

```bash
git add claude-config/agents/
git commit -m "feat: add 8 Claude Code agent definitions to claude-config/agents/"
```

---

## Chunk 2: Install Module + install.sh + entrypoint.sh

**Files:**
- Create: `install/agents.sh`
- Modify: `install.sh` (refactor `_run()`, add `do_agents`, `--agents` flag, menu option 7, `_usage`)
- Modify: `entrypoint.sh` (add agents copy block after hooks block)

---

### Task 10: Create install/agents.sh

- [ ] **Step 1: Create install/agents.sh**

```bash
#!/usr/bin/env bash
# install_agents: copy Claude Code agent definitions to ~/.claude/agents/
set -euo pipefail
# shellcheck source=install/common.sh
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
    warn "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS not set in settings.json — run --config first or agents may not activate"
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

- [ ] **Step 2: Make executable**

```bash
chmod +x install/agents.sh
```

- [ ] **Step 3: Verify syntax**

```bash
bash -n install/agents.sh && echo "syntax OK"
```

Expected: `syntax OK`

- [ ] **Step 4: Run it and verify agents are installed**

```bash
bash install/agents.sh
ls ~/.claude/agents/
```

Expected: 8 `.md` files listed.

- [ ] **Step 5: Run it again to verify skip-if-exists**

```bash
bash install/agents.sh 2>&1 | grep "already exists"
```

Expected: 8 lines containing "already exists — skipping".

---

### Task 11: Refactor install.sh — _run() and do_agents variable

- [ ] **Step 1: Refactor `_run()` to remove positional parameters**

In `install.sh`, replace:

```bash
_run() {
  local do_config=$1 do_tools=$2 do_mcp=$3 do_docker=$4 do_path=$5
  # shellcheck source=install/config.sh
  [[ "$do_config" == true ]] && { source "$SCRIPT_DIR/install/config.sh"; install_config; }
  # shellcheck source=install/tools.sh
  [[ "$do_tools"  == true ]] && { source "$SCRIPT_DIR/install/tools.sh";  install_tools;  }
  # shellcheck source=install/mcp.sh
  [[ "$do_mcp"    == true ]] && { source "$SCRIPT_DIR/install/mcp.sh";    install_mcp;    }
  # shellcheck source=install/docker.sh
  [[ "$do_docker" == true ]] && { source "$SCRIPT_DIR/install/docker.sh"; install_docker; }
  # shellcheck source=install/path.sh
  [[ "$do_path"   == true ]] && { source "$SCRIPT_DIR/install/path.sh";   install_path;   }
}
```

with:

```bash
_run() {
  # shellcheck source=install/config.sh
  [[ "$do_config" == true ]] && { source "$SCRIPT_DIR/install/config.sh"; install_config; }
  # shellcheck source=install/tools.sh
  [[ "$do_tools"  == true ]] && { source "$SCRIPT_DIR/install/tools.sh";  install_tools;  }
  # shellcheck source=install/mcp.sh
  [[ "$do_mcp"    == true ]] && { source "$SCRIPT_DIR/install/mcp.sh";    install_mcp;    }
  # shellcheck source=install/agents.sh
  [[ "$do_agents" == true ]] && { source "$SCRIPT_DIR/install/agents.sh"; install_agents; }
  # shellcheck source=install/docker.sh
  [[ "$do_docker" == true ]] && { source "$SCRIPT_DIR/install/docker.sh"; install_docker; }
  # shellcheck source=install/path.sh
  [[ "$do_path"   == true ]] && { source "$SCRIPT_DIR/install/path.sh";   install_path;   }
}
```

- [ ] **Step 2: Update `_menu()` — add do_agents local, option 7, update prompt and case 1**

Replace the `_menu()` function body:

```bash
_menu() {
  echo "What would you like to install?"
  echo ""
  echo "  1) All (config + tools + MCP + agents + path)"
  echo "  2) Claude Code config (CLAUDE.md, settings, hooks)"
  echo "  3) Tools (nvm, Node.js, Claude Code, dev tools)"
  echo "  4) MCP servers"
  echo "  5) Docker images"
  echo "  6) PATH + shell aliases"
  echo "  7) Claude Code agents"
  echo "  q) Quit"
  echo ""
  read -rp "Select (1-7, q, or multiple e.g. '2 3'): " selection
  echo ""

  local do_config=false do_tools=false do_mcp=false do_docker=false do_path=false do_agents=false
  for token in $selection; do
    case "$token" in
      1) do_config=true; do_tools=true; do_mcp=true; do_agents=true; do_path=true ;;
      2) do_config=true ;;
      3) do_tools=true ;;
      4) do_mcp=true ;;
      5) do_docker=true ;;
      6) do_path=true ;;
      7) do_agents=true ;;
      q) echo "Quit."; exit 0 ;;
      *) warn "Unknown option: $token" ;;
    esac
  done
  _run
}
```

- [ ] **Step 3: Update global variable declarations and flag-parsing block**

Replace:

```bash
do_config=false; do_tools=false; do_mcp=false; do_docker=false; do_path=false
skip_docker=false; do_all=false
```

with:

```bash
do_config=false; do_tools=false; do_mcp=false; do_docker=false; do_path=false
do_agents=false; skip_docker=false; do_all=false
```

In the `for arg in "$@"` case block, add after `--path)`:

```bash
    --agents)      do_agents=true ;;
```

- [ ] **Step 4: Update `--all` expansion to include agents**

Replace:

```bash
if [[ "$do_all" == true ]]; then
  do_config=true; do_tools=true; do_mcp=true; do_path=true
  [[ "$skip_docker" == false ]] && do_docker=true
fi
```

with:

```bash
if [[ "$do_all" == true ]]; then
  do_config=true; do_tools=true; do_mcp=true; do_agents=true; do_path=true
  [[ "$skip_docker" == false ]] && do_docker=true
fi
```

- [ ] **Step 5: Update the bottom-of-script `_run` call to remove positional arguments**

At the bottom of `install.sh` (line 127), replace:

```bash
_run "$do_config" "$do_tools" "$do_mcp" "$do_docker" "$do_path"
```

with:

```bash
_run
```

Note: `_menu`'s call was already replaced with a no-arg `_run` in Step 2. Only this one remaining call needs updating.

- [ ] **Step 6: Update `_usage()`**

Replace the `_usage` function body:

```bash
_usage() {
  echo "Usage: ./install.sh [OPTIONS]"
  echo ""
  echo "  (no flags)      Interactive menu"
  echo "  --all           Run all steps: config + tools + mcp + agents + docker + path"
  echo "  --config        Install Claude Code config files"
  echo "  --tools         Install nvm/node/claude + OS dev tools"
  echo "  --mcp           Install MCP servers"
  echo "  --agents        Install Claude Code agent definitions"
  echo "  --docker        Build Docker images"
  echo "  --path          Set up symlinks, claude wrapper, shell snippets"
  echo "  --skip-docker   Skip Docker build (for use with --all)"
  echo "  -h, --help      Show this help"
}
```

Also update the header comment block at the top of `install.sh`. Replace:

```bash
#   --all           Run all steps: config + tools + mcp + docker + path
#   --config        Install Claude Code config files
#   --tools         Install nvm/node/claude + OS dev tools
#   --mcp           Install MCP servers
#   --docker        Build Docker images
#   --path          Set up symlinks, claude wrapper, shell snippets
```

with:

```bash
#   --all           Run all steps: config + tools + mcp + agents + docker + path
#   --config        Install Claude Code config files
#   --tools         Install nvm/node/claude + OS dev tools
#   --mcp           Install MCP servers
#   --agents        Install Claude Code agent definitions
#   --docker        Build Docker images
#   --path          Set up symlinks, claude wrapper, shell snippets
```

- [ ] **Step 7: Verify syntax**

```bash
bash -n install.sh && echo "syntax OK"
```

Expected: `syntax OK`

- [ ] **Step 8: Smoke test --help**

```bash
bash install.sh --help
```

Expected: `--agents` appears in output with description.

- [ ] **Step 9: Smoke test --agents flag**

```bash
# Remove installed agents first to test fresh install
rm -f ~/.claude/agents/research.md
bash install.sh --agents 2>&1 | head -20
```

Expected: `[OK]   research.md installed` and all others show "already exists — skipping".

---

### Task 12: Update entrypoint.sh — agents copy block

- [ ] **Step 1: Add agents copy block after the hooks block**

In `entrypoint.sh`, insert directly after the hooks block. The hooks block ends at line 53 and is immediately followed by the MCP patch block — there is no blank line between them, so insert a blank line + the new block between them:

```bash
# --- Copy hook scripts ---
if [ -d /opt/claude-config/hooks ]; then
  mkdir -p /home/agent/.claude/hooks
  cp /opt/claude-config/hooks/*.sh /home/agent/.claude/hooks/
  chmod +x /home/agent/.claude/hooks/*.sh
fi

# --- Copy agent definitions ---
if [ -d /opt/claude-config/agents ]; then
  mkdir -p /home/agent/.claude/agents
  cp /opt/claude-config/agents/*.md /home/agent/.claude/agents/
fi

# --- Patch MCP env var placeholders in settings.json ---
```

The full replacement shown above ensures the agents block is placed between hooks and the MCP patch section. Use the Edit tool with `old_string` matching the existing hooks block + start of the MCP comment to pinpoint the insertion.

```bash
# --- Copy agent definitions ---
if [ -d /opt/claude-config/agents ]; then
  mkdir -p /home/agent/.claude/agents
  cp /opt/claude-config/agents/*.md /home/agent/.claude/agents/
fi
```

- [ ] **Step 2: Verify syntax**

```bash
bash -n entrypoint.sh && echo "syntax OK"
```

Expected: `syntax OK`

---

### Task 13: Final verification and commit

- [ ] **Step 1: Verify all changed files have LF line endings**

```bash
file install/agents.sh install.sh entrypoint.sh
```

Expected: no CRLF in output.

- [ ] **Step 2: Count agent files in repo**

```bash
ls claude-config/agents/*.md | wc -l
```

Expected: `8`

- [ ] **Step 3: Verify install.sh _run() has no positional params**

```bash
grep -n '_run' install.sh
```

Expected: `_run()` definition line and two bare `_run` calls (one in `_menu`, one at bottom of script) — no line shows `_run "$do_`.

- [ ] **Step 4: Verify --agents appears in --all expansion**

```bash
grep "do_agents" install.sh
```

Expected: at least 3 lines — declaration, `--agents` flag case, and `--all` block.

- [ ] **Step 5: Commit everything**

```bash
git add install/agents.sh install.sh entrypoint.sh
git commit -m "feat: add --agents install step and refactor _run() to scope-read vars"
```
