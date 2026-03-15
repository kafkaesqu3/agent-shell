# AI Agent Shell

A portable AI development environment — either as a Docker container you launch in any project directory, or installed directly on a host/VPS. Bundles Claude Code with MCP servers, multiple AI tools, and best-practices configuration.

## Quickstart

```bash
git clone <this-repo> ~/ai-agent-shell
cd ~/ai-agent-shell

# Copy and fill in your API keys
cp .env.example ~/.config/ai-agent/.env
# edit ~/.config/ai-agent/.env

# Build Docker images
docker build --target lite     -t ai-agent:lite .      # Claude Code only (fast)
docker build --target base     -t ai-agent:latest .    # full dev environment
docker build --target browsing -t ai-agent:browsing .  # full + browser automation
docker compose up ai-agent-lite      # Claude Code only
docker compose up ai-agent           # full dev environment
docker compose up ai-agent-browsing  # full + browser automation

# Run host installation
./install.sh --all                # everything
./install.sh --config             # Claude config files only
./install.sh --tools              # fnm, Node.js, Claude Code, OS dev tools
./install.sh --mcp                # MCP servers
./install.sh --agents             # agent definitions
./install.sh --docker             # build Docker images
./install.sh --path               # PATH, symlinks, shell snippets

# Launch container (mounts CWD as /workspace)
./ai-agent.sh                     # Linux/macOS
./ai-agent.ps1                    # Windows PowerShell

# Test entrypoint logic
bash entrypoint.sh claude         # dry-run entrypoint

# Paste the shell snippets printed by install.sh into ~/.zshrc or ~/.bashrc
# (includes fnm init + claude wrapper function)
source ~/.zshrc   # or ~/.bashrc

# Done — run claude from any project
cd ~/projects/my-app
claude            # runs Claude Code inside Docker
claude --host     # runs Claude Code locally on the host
```

**Windows (PowerShell):** paste the function printed by `install.sh` into your PowerShell profile, then use `claude` or `ai-agent.ps1` directly.

### Install Modules

`install.sh` delegates to modular scripts in `install/`:

- `common.sh` — shared utilities (color output, `cmd_exists`, `detect_os`)
- `config.sh` — installs `claude-config/` files to `~/.claude/`
- `tools.sh` — fnm, Node.js 22 LTS, Claude Code, OS dev tools
- `mcp.sh` — MCP servers (npm global + Python venv)
- `agents.sh` — agent definitions to `~/.claude/agents/`
- `docker.sh` — builds Docker images
- `path.sh` — symlinks, `claude-wrapper.sh`, shell rc snippets

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
- Node.js 22 LTS via [fnm](https://github.com/Schniz/fnm) (fast, per-directory version switching), Python 3.12, Go 1.23
- Git, GitHub CLI (`gh`), `jq`, `curl`
- `ripgrep`, `fd`, `fzf`, `tmux` baked in

### Shell
- **zsh** is the default shell with history (200k lines), completion, and auto-cd
- **fzf** wired to `fd` for fast, `.gitignore`-aware fuzzy file finding
- **`claude-yolo`** alias for `claude --dangerously-skip-permissions`
- **tmux** pre-configured with mouse support, vi keys, true colour, and large scrollback

### Claude Code Configuration
- **Statusline** — two-line prompt with model, cost, context %, session time
- **Safety guardrails** — blocks `rm -rf`, force-push, direct push to main/master
- **Credential protection** — denies reading SSH keys, AWS/GCP creds, wallet files, and the baked config dir (`/opt/claude-config`)
- **npm supply-chain hardening** — exact version pinning, 24-hour publish delay, postinstall scripts disabled
- **Onboarding bypass** — headless containers start non-interactively when `CLAUDE_CODE_OAUTH_TOKEN` is set
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
- Node.js 22 via fnm (installs fnm if missing)
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

Three image targets are available depending on how much you need:

| Target | Tag | Contents |
|--------|-----|----------|
| `lite` | `ai-agent:lite` | Claude Code only — fastest build, smallest image |
| `base` | `ai-agent:latest` | Full dev environment: Go, GitHub CLI, MCP servers, AI tools |
| `browsing` | `ai-agent:browsing` | Everything in `base` + Chromium, Puppeteer, Playwright |

Each target inherits from the one above (`lite` → `base` → `browsing`), so Docker cache is shared.

```bash
# Claude Code only (fastest build)
docker build -t ai-agent:lite --target lite .

# Full dev environment (default)
docker build -t ai-agent:latest --target base .

# Full + browser automation
docker build -t ai-agent:browsing --target browsing .
```

Or use `install.sh --docker` for an interactive menu that lets you choose which to build:

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
claude            # runs Claude Code inside the Docker container
claude --host     # runs Claude Code directly on the host (bypasses Docker)
ai-agent          # launches an interactive shell in the container
```

The launcher auto-detects `.env` from:
1. `--env <path>` flag
2. `.env` in the current directory
3. `.env` in the script directory
4. `~/.config/ai-agent/.env`

---

## Configuration Layering

Config files are baked into the Docker image from `claude-config/` and always written to the container on startup — so rebuilding the image is all you need to pick up changes. Credentials and session history persist in a named volume across restarts.

```
claude-config/          ← source of truth (edit here, then rebuild)
        ↓
docker build            ← bakes into /opt/claude-config/ inside image
        ↓
entrypoint.sh           ← writes to /home/agent/.claude/ on every start
                           patches __GITHUB_TOKEN__ / __BRAVE_API_KEY__ from env
                           skips .credentials.json if already present
        ↓
ai-agent-claude volume  ← persists credentials + session history across restarts
```

To update config: edit `claude-config/`, rebuild (`docker build` or `./install.sh --docker`), restart.

---

## File Structure

```
agent-shell/
├── Dockerfile              # Multi-stage: lite, base, browsing targets
├── docker-compose.yml      # Three services: ai-agent-lite, ai-agent, ai-agent-browsing
├── entrypoint.sh           # Config layering, credential setup, statusline install
├── install.sh              # Host/VPS installer (Claude Code + MCP + config)
├── ai-agent.sh             # Bash launcher (add to PATH)
├── ai-agent.ps1            # PowerShell launcher (Windows)
├── claude-wrapper.sh       # claude → container, claude --host → local
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
docker compose up ai-agent-lite     # Claude Code only
docker compose up ai-agent          # full dev environment
docker compose up ai-agent-browsing # full + browser automation
```

### Multiple simultaneous sessions

Each `ai-agent` call spawns an independent container sharing the same project files:

```bash
# Terminal 1 — project A
cd ~/projects/project-a && ai-agent

# Terminal 2 — project B
cd ~/projects/project-b && ai-agent
```

### Lite image

For a fast-starting container with only Claude Code (no Go, MCP servers, AI tools):

```bash
ai-agent --lite          # uses ai-agent:lite image
docker compose up ai-agent-lite
```

### Session sync

Copies Claude session logs from a container to your host so `/insights` works across sessions:

```bash
cd ~/projects/my-app
ai-agent sync            # syncs from container named after the current directory
ai-agent --name my-session sync   # sync from a named container
```

Session logs land in `~/.claude/projects/` on the host. Works with both running and stopped containers.

### Network isolation (for untrusted repos)

The `base` and `browsing` services include `NET_ADMIN` and `NET_RAW` capabilities, enabling iptables-based outbound filtering. To allowlist only known-good hosts:

```bash
# Inside the container — restrict outbound to GitHub, npm, PyPI, Anthropic
iptables -P OUTPUT DROP
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -d api.anthropic.com -j ACCEPT
iptables -A OUTPUT -d registry.npmjs.org -j ACCEPT
iptables -A OUTPUT -d pypi.org,files.pythonhosted.org -j ACCEPT
iptables -A OUTPUT -d github.com,api.github.com -j ACCEPT
iptables -A OUTPUT -d go.dev,proxy.golang.org,sum.golang.org -j ACCEPT
```

### Per-project .env

```bash
cd ~/projects/client-project
cp ~/.config/ai-agent/.env .env
# edit .env with project-specific keys
ai-agent   # picks up .env in current directory automatically
```

### Updating config (Docker)

Edit files in `claude-config/`, then rebuild and restart:

```bash
docker build -t ai-agent:latest --target base .  # or :lite / :browsing
ai-agent   # entrypoint writes fresh config on every start
```

---

## install.sh flags

```
./install.sh              # interactive menu
./install.sh --all        # config + tools + mcp + agents + docker + path
./install.sh --config     # Claude Code config files only
./install.sh --tools      # fnm, Node.js, Claude Code, OS dev tools
./install.sh --mcp        # MCP servers
./install.sh --agents     # agent definitions
./install.sh --docker     # build Docker images (interactive: lite / base / browsing / all)
./install.sh --path       # symlinks, claude wrapper, shell snippets
./install.sh --skip-docker  # skip Docker when used with --all
```
