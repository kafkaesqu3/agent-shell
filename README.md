# AI Agent Shell

A portable AI development environment — either as a Docker container you launch in any project directory, or installed directly on a host/VPS. Bundles Claude Code with MCP servers, multiple AI tools, and best-practices configuration.

## What's Included

### AI Assistants
| Tool | Description |
|------|-------------|
| `claude` | Claude Code — Anthropic's agentic coding CLI |
| `aider` | AI pair programming (supports Claude, GPT-4, Gemini) |
| `sgpt` | Shell-GPT — natural language shell commands |
| `gemini` | Google Gemini CLI |
| `fabric` | AI patterns framework |

### MCP Servers (Claude Code extensions)
| Server | Purpose |
|--------|---------|
| `fetch` | Fetch and read web pages |
| `filesystem` | Scoped file access at `/workspace` |
| `github` | GitHub API (PRs, issues, repos) |
| `sqlite` | Query SQLite databases |
| `context7` | Up-to-date library documentation |
| `sequential-thinking` | Structured multi-step reasoning |
| `brave-search` | Web search via Brave |
| `puppeteer` | Browser automation _(browsing image only)_ |
| `playwright` | Browser automation/testing _(browsing image only)_ |

### Runtimes & Tools
- Node.js 22 LTS, Python 3.12, Go 1.23
- Git, GitHub CLI (`gh`), `jq`, `curl`

### Claude Code Configuration
- **Statusline** — two-line prompt with model, cost, context %, session time
- **Safety guardrails** — blocks `rm -rf`, force-push, direct push to main/master
- **Credential protection** — denies reading SSH keys, AWS/GCP creds, wallet files
- **Telemetry disabled** — no usage reporting or feedback surveys
- **Always-thinking mode** enabled

---

## Install Options

### Option A: Host / VPS install (no Docker)

Installs Claude Code, all MCP servers, and config files directly on the host:

```bash
git clone <this-repo> ~/ai-agent-shell
cd ~/ai-agent-shell
./install.sh
```

This installs:
- Node.js 22 (auto-installs via nodesource if missing)
- `claude` CLI
- All npm MCP servers globally
- `mcp-server-fetch` in an isolated Python venv → symlinked to `~/.local/bin`
- `~/.claude/CLAUDE.md` (appends if file exists)
- `~/.claude/settings.json` (merges MCP servers if file exists; backs up original)
- `~/.claude/statusline.sh`
- `ai-agent` symlink in `~/.local/bin` (adds to PATH if needed)

To also install dev tools (ripgrep, shellcheck, uv, ruff, cargo tools, etc.):

```bash
./claude-config/setup.sh
```

After install, set your API keys (add to `~/.bashrc` or `~/.zshrc`):

```bash
export ANTHROPIC_API_KEY=sk-ant-...
export GITHUB_TOKEN=ghp_...
export BRAVE_API_KEY=...
```

Or patch the placeholders directly in `~/.claude/settings.json`:

```bash
sed -i 's/__GITHUB_TOKEN__/ghp_yourtoken/g' ~/.claude/settings.json
sed -i 's/__BRAVE_API_KEY__/yourbravkey/g' ~/.claude/settings.json
```

Then authenticate:

```bash
claude   # follows prompts to log in via claude.ai or API key
```

---

### Option B: Docker container

Build once, launch in any project directory.

#### Build

```bash
# Base image (all AI tools, no browser)
docker build -t ai-agent:latest --target base .

# Optional: browsing variant (adds Chromium, Puppeteer, Playwright)
docker build -t ai-agent-browsing:latest --target browsing .
```

Or use `install.sh --docker` to build as part of the full install:

```bash
./install.sh --docker
```

#### Configure API keys

Create a `.env` file (gitignored). Pick a preset or start from the example:

```bash
cp .env.example ~/.config/ai-agent/.env   # recommended: central location
# or
cp .env.claude .env    # Claude-only
cp .env.full .env      # all providers
cp .env.browsing .env  # browsing + search focused
```

Edit the file and fill in your keys:

```env
ANTHROPIC_API_KEY=sk-ant-...
GITHUB_TOKEN=ghp_...
BRAVE_API_KEY=...
OPENAI_API_KEY=sk-...    # optional
GOOGLE_API_KEY=...        # optional
```

#### Add launcher to PATH

```bash
# Linux/Mac
./install.sh --path-only
# Symlinks ai-agent.sh → ~/.local/bin/ai-agent

# Windows PowerShell — add this directory to your PATH manually
# then use ai-agent.ps1
```

#### Daily use

```bash
cd ~/projects/my-app
ai-agent          # launches container with current dir mounted at /workspace
```

The launcher auto-detects `.env` from:
1. `--env <path>` flag
2. `.env` in the current directory
3. `.env` in the script directory
4. `~/.config/ai-agent/.env`

If your host has `~/.claude/CLAUDE.md` or `~/.claude/settings.json`, they are mounted into the container as overrides — your local config takes priority over the baked defaults.

---

## Configuration Layering

Both install modes use the same layered config strategy:

```
/opt/claude-config/     ← baked defaults (CLAUDE.md, settings.json, statusline.sh)
        ↓
~/.claude/*.host        ← host mounts (Docker) or existing files (host install)
        ↓
entrypoint.sh patches   ← replaces __GITHUB_TOKEN__ / __BRAVE_API_KEY__ placeholders
        ↓
Claude Code starts with merged config
```

In Docker, baked defaults apply on first run. Once the `ai-agent-claude` volume has a `settings.json`, it persists across containers. Mounting your host `~/.claude/settings.json` as `.host` overrides the baked version on every launch.

---

## File Structure

```
agent-shell/
├── Dockerfile              # Multi-stage: base + browsing targets
├── docker-compose.yml      # Two services: ai-agent, ai-agent-browsing
├── entrypoint.sh           # Config layering, credential setup, statusline install
├── install.sh              # Host/VPS installer (Claude Code + MCP + config)
├── ai-agent.sh             # Bash launcher (add to PATH)
├── ai-agent.ps1            # PowerShell launcher (Windows)
├── claude-config/
│   ├── CLAUDE.md           # Default system instructions
│   ├── settings.json       # MCP servers, permissions, hooks, statusline
│   ├── statusline.sh       # Two-line Claude Code statusline script
│   └── setup.sh            # Dev tool installer (ripgrep, uv, cargo tools, etc.)
├── .env.example            # Template — all keys
├── .env.claude             # Preset — Claude only
├── .env.full               # Preset — all providers
└── .env.browsing           # Preset — browsing + search
```

---

## Usage

### Claude Code

```bash
claude                              # interactive session
claude "explain this codebase"
claude "add error handling to app.js"
claude "refactor to use async/await"
```

### Aider

```bash
aider                               # uses Claude by default
aider --model gpt-4o src/app.js
aider --model gemini/gemini-pro
```

### Shell-GPT

```bash
sgpt "how do I find large files"
sgpt --shell "find files modified in last 7 days"
sgpt --shell --execute "create a backup of all .js files"
sgpt --code "python function to parse JSON"
```

### Fabric

```bash
fabric --setup                      # first-time setup
fabric --list                       # show available patterns
cat article.md | fabric --pattern extract_wisdom
cat docs.md | fabric --pattern summarize
```

### Pass a command directly (Docker)

```bash
ai-agent bash -c "claude 'summarize main.py'"
ai-agent --env ~/.config/ai-agent/.env.client bash
```

### Start a named container manually

```bash
# Interactive shell with a named container (removed on exit)
docker run -it --rm --name my-session -v $(pwd):/workspace ai-agent:latest

# Attach to a running named container from another terminal
docker exec -it my-session bash

# Keep running in the background, attach later
docker run -d --name my-session -v $(pwd):/workspace ai-agent:latest sleep infinity
docker exec -it my-session bash
```

---

## Advanced

### docker-compose

```bash
docker compose up ai-agent          # base variant
docker compose up ai-agent-browsing # browsing variant
```

### Multiple simultaneous sessions

Each `ai-agent` call spawns an independent container sharing the same project files:

```bash
# Terminal 1 — project A
cd ~/projects/project-a && ai-agent

# Terminal 2 — project B
cd ~/projects/project-b && ai-agent
```

### Per-project .env

```bash
cd ~/projects/client-project
cp ~/.config/ai-agent/.env .env
# edit .env with project-specific keys
ai-agent   # picks up .env in current directory automatically
```

### Override config without rebuilding (Docker)

Mount your host config directly:

```bash
# Uncomment in docker-compose.yml:
# - ~/.claude/CLAUDE.md:/root/.claude/CLAUDE.md.host:ro
# - ~/.claude/settings.json:/root/.claude/settings.json.host:ro
```

Or the launcher does this automatically if those files exist on your host.

---

## install.sh flags

```
./install.sh              # config + tools + PATH (no Docker)
./install.sh --docker     # same + build Docker images
./install.sh --docker-only
./install.sh --config-only
./install.sh --path-only
./install.sh --no-tools
./install.sh --no-path
```
