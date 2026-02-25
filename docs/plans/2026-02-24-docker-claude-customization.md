# Enhanced AI Agent Docker Container — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Transform the AI agent Docker container into a fully customized Claude Code power-user environment with baked-in MCP servers, layered CLAUDE.md, and runtime config merging.

**Architecture:** Single multi-stage Dockerfile with `ENABLE_BROWSING` build arg. An entrypoint script layers baked defaults with optional host-mounted overrides and patches environment variables into MCP configs at startup.

**Tech Stack:** Docker multi-stage builds, bash entrypoint, Claude Code settings.json, MCP server npm packages

---

### Task 1: Create `claude-config/` directory with baked defaults

**Files:**
- Create: `claude-config/CLAUDE.md`
- Create: `claude-config/settings.json`

**Step 1: Create the baked CLAUDE.md**

```markdown
Always use Context7 MCP when I need library/API documentation, code generation, setup or configuration steps without me having to explicitly ask.
```

This is copied from the user's current `~/.claude/CLAUDE.md`.

**Step 2: Create the baked settings.json with MCP servers**

```json
{
  "mcpServers": {
    "fetch": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-fetch"]
    },
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/workspace"]
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "__GITHUB_TOKEN__"
      }
    },
    "sqlite": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-sqlite"]
    },
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp"]
    },
    "sequential-thinking": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"]
    },
    "brave-search": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-brave-search"],
      "env": {
        "BRAVE_API_KEY": "__BRAVE_API_KEY__"
      }
    },
    "puppeteer": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-puppeteer"]
    },
    "playwright": {
      "command": "npx",
      "args": ["-y", "@playwright/mcp", "--headless"]
    }
  }
}
```

Placeholder tokens (`__GITHUB_TOKEN__`, `__BRAVE_API_KEY__`) are replaced by the entrypoint at runtime.

**Step 3: Verify files exist**

Run: `ls -la claude-config/`
Expected: `CLAUDE.md` and `settings.json` present

---

### Task 2: Create `entrypoint.sh`

**Files:**
- Create: `entrypoint.sh`

**Step 1: Write the entrypoint script**

```bash
#!/bin/bash
# AI Agent Container Entrypoint
# Layers baked defaults with host-mounted overrides and patches env vars

set -e

CLAUDE_DIR="/root/.claude"
BAKED_DIR="/opt/claude-config"

# --- CLAUDE.md layering ---
# If host mounted a CLAUDE.md override, use it
if [ -f "$CLAUDE_DIR/CLAUDE.md.host" ]; then
    cp "$CLAUDE_DIR/CLAUDE.md.host" "$CLAUDE_DIR/CLAUDE.md"
elif [ ! -f "$CLAUDE_DIR/CLAUDE.md" ]; then
    # No host mount and no existing CLAUDE.md — use baked default
    cp "$BAKED_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
fi

# --- settings.json layering ---
# If host mounted a settings override, use it; otherwise use baked
if [ -f "$CLAUDE_DIR/settings.json.host" ]; then
    cp "$CLAUDE_DIR/settings.json.host" "$CLAUDE_DIR/settings.json"
elif [ ! -f "$CLAUDE_DIR/settings.json" ]; then
    cp "$BAKED_DIR/settings.json" "$CLAUDE_DIR/settings.json"
fi

# --- Patch MCP env var placeholders ---
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

if [ -f "$SETTINGS_FILE" ]; then
    # Replace placeholder tokens with actual env var values
    if [ -n "$GITHUB_TOKEN" ]; then
        sed -i "s|__GITHUB_TOKEN__|$GITHUB_TOKEN|g" "$SETTINGS_FILE"
    fi
    if [ -n "$BRAVE_API_KEY" ]; then
        sed -i "s|__BRAVE_API_KEY__|$BRAVE_API_KEY|g" "$SETTINGS_FILE"
    fi
fi

# --- Credentials ---
# If CLAUDE_CODE_OAUTH_TOKEN is set and no credentials file exists, write one
if [ -n "$CLAUDE_CODE_OAUTH_TOKEN" ] && [ ! -f "$CLAUDE_DIR/.credentials.json" ]; then
    cat > "$CLAUDE_DIR/.credentials.json" <<EOF
{
  "claudeAiOauth": {
    "token": "$CLAUDE_CODE_OAUTH_TOKEN"
  }
}
EOF
    chmod 600 "$CLAUDE_DIR/.credentials.json"
fi

# Ensure proper permissions
chmod -R 700 "$CLAUDE_DIR" 2>/dev/null || true

# Execute the requested command (default: bash)
exec "$@"
```

**Step 2: Make it executable**

Run: `chmod +x entrypoint.sh`

**Step 3: Verify**

Run: `head -1 entrypoint.sh`
Expected: `#!/bin/bash`

---

### Task 3: Rewrite the Dockerfile as multi-stage with build arg

**Files:**
- Modify: `Dockerfile`

**Step 1: Rewrite the Dockerfile**

```dockerfile
FROM node:22-slim AS base

# Install system dependencies
RUN apt-get update && apt-get install -y \
    bash \
    git \
    curl \
    wget \
    python3 \
    python3-pip \
    python3-venv \
    ca-certificates \
    vim \
    jq \
    iputils-ping \
    dnsutils \
    iproute2 \
    net-tools \
    && rm -rf /var/lib/apt/lists/*

# Install newer Go version
RUN curl -fsSL https://go.dev/dl/go1.23.5.linux-amd64.tar.gz -o go.tar.gz \
    && tar -C /usr/local -xzf go.tar.gz \
    && rm go.tar.gz
ENV PATH="/usr/local/go/bin:${PATH}"

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js-based AI tools
RUN npm install -g \
    @anthropic-ai/claude-code \
    @openai/codex \
    openai \
    @google/generative-ai \
    @google/gemini-cli

# Install MCP servers (base set — no browser needed)
RUN npm install -g \
    @modelcontextprotocol/server-fetch \
    @modelcontextprotocol/server-filesystem \
    @modelcontextprotocol/server-github \
    @modelcontextprotocol/server-sqlite \
    @modelcontextprotocol/server-brave-search \
    @modelcontextprotocol/server-sequential-thinking \
    @upstash/context7-mcp

# Install Python-based AI tools
RUN pip3 install --no-cache-dir --break-system-packages \
    aider-chat \
    shell-gpt \
    openai \
    anthropic \
    google-generativeai \
    google-ai-generativelanguage

# Install Fabric (AI patterns framework)
RUN go install github.com/danielmiessler/fabric/cmd/fabric@latest

# Set up environment
ENV PATH="/root/go/bin:${PATH}"
ENV SHELL=/bin/bash

# Create config directories
RUN mkdir -p /root/.claude \
    && mkdir -p /root/.config/claude \
    && mkdir -p /root/.config/fabric \
    && mkdir -p /root/.config/gemini \
    && mkdir -p /root/.aider

# Copy baked Claude Code configuration
COPY claude-config/ /opt/claude-config/
COPY entrypoint.sh /opt/entrypoint.sh
RUN chmod +x /opt/entrypoint.sh

WORKDIR /workspace

ENTRYPOINT ["/opt/entrypoint.sh"]
CMD ["bash"]

# ==============================================================================
# Browsing stage: adds chromium, playwright, puppeteer
# ==============================================================================
FROM base AS browsing

RUN apt-get update && apt-get install -y \
    chromium \
    chromium-driver \
    && rm -rf /var/lib/apt/lists/*

# Install browser MCP servers
RUN npm install -g \
    @modelcontextprotocol/server-puppeteer \
    @playwright/mcp

# Install Playwright dependencies
RUN pip3 install --no-cache-dir --break-system-packages \
    playwright \
    beautifulsoup4
RUN npx playwright install --with-deps chromium

ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium

# ==============================================================================
# Final stage: selected by ENABLE_BROWSING build arg
# ==============================================================================
ARG ENABLE_BROWSING=false
FROM ${ENABLE_BROWSING:+browsing}${ENABLE_BROWSING:-base} AS final
```

Note: Docker's conditional `FROM` using build args requires a specific pattern. The above uses a simpler approach — see Step 2 for the alternative if the ternary `FROM` doesn't work in all Docker versions.

**Step 2: Alternative — use a target-based approach (more portable)**

Instead of the conditional `FROM`, use Docker `--target`:

- `docker build --target base -t ai-agent:latest .` (no browsing)
- `docker build --target browsing -t ai-agent:latest .` (with browsing)

This is simpler and more portable. The Dockerfile stays the same but drops the final `ARG`/`FROM` block. The `docker-compose.yml` and launcher scripts use `--target` instead.

Recommend: **Use the target-based approach.** Remove the final `ARG`/`FROM` block from the Dockerfile.

**Step 3: Verify Dockerfile syntax**

Run: `docker build --target base --no-cache -t ai-agent:test . 2>&1 | tail -5`
Expected: `Successfully tagged ai-agent:test`

**Step 4: Commit**

```bash
git add Dockerfile claude-config/ entrypoint.sh
git commit -m "feat: multi-stage Dockerfile with Claude Code config and MCP servers"
```

---

### Task 4: Update `docker-compose.yml`

**Files:**
- Modify: `docker-compose.yml`

**Step 1: Rewrite docker-compose.yml**

```yaml
services:
  ai-agent:
    build:
      context: .
      target: base
    image: ai-agent:latest
    container_name: ai-agent
    stdin_open: true
    tty: true
    env_file:
      - .env
    volumes:
      # Mount current directory to /workspace
      - .:/workspace
      # Persistent Claude Code state (credentials, history, settings)
      - ai-agent-claude:/root/.claude
      # Persistent AI tool configurations
      - ai-agent-config:/root/.config
      # Optional: Host CLAUDE.md override (uncomment if you have one)
      # - ~/.claude/CLAUDE.md:/root/.claude/CLAUDE.md.host:ro
      # Optional: Host settings override (uncomment if you have one)
      # - ~/.claude/settings.json:/root/.claude/settings.json.host:ro
      # Optional: Share git config from host
      # - ~/.gitconfig:/root/.gitconfig:ro
    working_dir: /workspace

  # Full variant with browser automation
  ai-agent-browsing:
    build:
      context: .
      target: browsing
    image: ai-agent-browsing:latest
    container_name: ai-agent-browsing
    stdin_open: true
    tty: true
    env_file:
      - .env
    volumes:
      - .:/workspace
      - ai-agent-claude:/root/.claude
      - ai-agent-config:/root/.config
    working_dir: /workspace

volumes:
  ai-agent-claude:
    name: ai-agent-claude
  ai-agent-config:
    name: ai-agent-config
```

**Step 2: Verify syntax**

Run: `docker compose config --quiet 2>&1; echo "exit: $?"`
Expected: `exit: 0`

**Step 3: Commit**

```bash
git add docker-compose.yml
git commit -m "feat: docker-compose with build targets and persistent volumes"
```

---

### Task 5: Update `ai-agent.sh` launcher

**Files:**
- Modify: `ai-agent.sh`

**Step 1: Rewrite ai-agent.sh**

```bash
#!/bin/bash
# AI Agent Container Launcher
# Maps current directory to /workspace and runs with layered Claude Code config

# Configuration
ENV_FILE="$HOME/.config/ai-agent/.env"
CLAUDE_HOME="$HOME/.claude"
IMAGE_NAME="ai-agent:latest"
VOLUME_NAME="ai-agent-claude"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}AI Agent Container${NC}"
echo "Working directory: $(pwd)"
echo ""

# Check Docker
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}Docker is not running!${NC}"
    echo "Please start Docker and try again."
    exit 1
fi
echo -e "${GREEN}Docker is running${NC}"

# Build docker run command
DOCKER_CMD="docker run -it --rm"

# Load .env and pass vars
if [ -f "$ENV_FILE" ]; then
    echo -e "${GREEN}Loading API keys from: $ENV_FILE${NC}"
    while IFS= read -r line; do
        if [[ -n "$line" && ! "$line" =~ ^[[:space:]]*# ]]; then
            key=$(echo "$line" | cut -d= -f1)
            DOCKER_CMD="$DOCKER_CMD -e $key"
        fi
    done < "$ENV_FILE"
    set -a
    source "$ENV_FILE"
    set +a
else
    echo -e "${YELLOW}No .env file found at: $ENV_FILE${NC}"
    echo "  Container will start without API keys."
    echo ""
    echo "Create .env with: ANTHROPIC_API_KEY, OPENAI_API_KEY, GITHUB_TOKEN, BRAVE_API_KEY"
fi

echo ""

# Volume: current directory
DOCKER_CMD="$DOCKER_CMD -v $(pwd):/workspace"

# Volume: persistent Claude state
DOCKER_CMD="$DOCKER_CMD -v $VOLUME_NAME:/root/.claude"

# Optional: host CLAUDE.md override
if [ -f "$CLAUDE_HOME/CLAUDE.md" ]; then
    DOCKER_CMD="$DOCKER_CMD -v $CLAUDE_HOME/CLAUDE.md:/root/.claude/CLAUDE.md.host:ro"
    echo -e "${GREEN}Mounting host CLAUDE.md${NC}"
fi

# Optional: host settings.json override
if [ -f "$CLAUDE_HOME/settings.json" ]; then
    DOCKER_CMD="$DOCKER_CMD -v $CLAUDE_HOME/settings.json:/root/.claude/settings.json.host:ro"
    echo -e "${GREEN}Mounting host settings.json${NC}"
fi

# Optional: host credentials
if [ -f "$CLAUDE_HOME/.credentials.json" ]; then
    DOCKER_CMD="$DOCKER_CMD -v $CLAUDE_HOME/.credentials.json:/root/.claude/.credentials.json:ro"
    echo -e "${GREEN}Mounting host credentials${NC}"
fi

# Optional: git config
if [ -f "$HOME/.gitconfig" ]; then
    DOCKER_CMD="$DOCKER_CMD -v $HOME/.gitconfig:/root/.gitconfig:ro"
fi

DOCKER_CMD="$DOCKER_CMD -w /workspace"
DOCKER_CMD="$DOCKER_CMD $IMAGE_NAME"

# Pass through any arguments
if [ $# -gt 0 ]; then
    DOCKER_CMD="$DOCKER_CMD $@"
fi

echo ""
echo -e "${GREEN}Available AI tools:${NC}"
echo "  - claude         (Anthropic Claude Code)"
echo "  - aider          (AI pair programming)"
echo "  - sgpt           (Shell-GPT)"
echo "  - gemini         (Google Gemini)"
echo "  - gh copilot     (GitHub Copilot CLI)"
echo "  - fabric         (AI patterns)"
echo ""
echo "Type 'exit' to leave the container"
echo "===================================="
echo ""

eval $DOCKER_CMD
```

**Step 2: Commit**

```bash
git add ai-agent.sh
git commit -m "feat: launcher mounts host Claude configs and uses persistent volume"
```

---

### Task 6: Update `ai-agent.ps1` launcher

**Files:**
- Modify: `ai-agent.ps1`

**Step 1: Rewrite ai-agent.ps1**

```powershell
# AI Agent Container Launcher (PowerShell)
# Maps current directory to /workspace and runs with layered Claude Code config

# Configuration
$EnvFile = "$env:USERPROFILE\.config\ai-agent\.env"
$ClaudeHome = "$env:USERPROFILE\.claude"
$ImageName = "ai-agent:latest"
$VolumeName = "ai-agent-claude"

Write-Host "AI Agent Container" -ForegroundColor Cyan
Write-Host "Working directory: $(Get-Location)"
Write-Host ""

# Check Docker
try {
    docker info 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Docker not running" }
} catch {
    Write-Host "Docker is not running!" -ForegroundColor Red
    Write-Host "Please start Docker Desktop and try again."
    exit 1
}
Write-Host "Docker is running" -ForegroundColor Green

# Build docker args
$DockerArgs = @("run", "-it", "--rm")

# Load .env and pass vars
if (Test-Path $EnvFile) {
    Write-Host "Loading API keys from: $EnvFile" -ForegroundColor Green
    Get-Content $EnvFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith('#')) {
            if ($line -match '^([^=]+)=(.*)$') {
                $key = $matches[1]
                $value = $matches[2]
                $DockerArgs += "-e"
                $DockerArgs += $key
                [Environment]::SetEnvironmentVariable($key, $value, 'Process')
            }
        }
    }
} else {
    Write-Host "No .env file found at: $EnvFile" -ForegroundColor Yellow
    Write-Host "  Container will start without API keys."
    Write-Host ""
    Write-Host "Create .env with: ANTHROPIC_API_KEY, OPENAI_API_KEY, GITHUB_TOKEN, BRAVE_API_KEY"
}

Write-Host ""

# Volume: current directory
$CurrentDir = (Get-Location).Path
$DockerArgs += "-v"
$DockerArgs += "${CurrentDir}:/workspace"

# Volume: persistent Claude state
$DockerArgs += "-v"
$DockerArgs += "${VolumeName}:/root/.claude"

# Optional: host CLAUDE.md override
$ClaudeMd = Join-Path $ClaudeHome "CLAUDE.md"
if (Test-Path $ClaudeMd) {
    $DockerArgs += "-v"
    $DockerArgs += "${ClaudeMd}:/root/.claude/CLAUDE.md.host:ro"
    Write-Host "Mounting host CLAUDE.md" -ForegroundColor Green
}

# Optional: host settings.json override
$ClaudeSettings = Join-Path $ClaudeHome "settings.json"
if (Test-Path $ClaudeSettings) {
    $DockerArgs += "-v"
    $DockerArgs += "${ClaudeSettings}:/root/.claude/settings.json.host:ro"
    Write-Host "Mounting host settings.json" -ForegroundColor Green
}

# Optional: host credentials
$ClaudeCreds = Join-Path $ClaudeHome ".credentials.json"
if (Test-Path $ClaudeCreds) {
    $DockerArgs += "-v"
    $DockerArgs += "${ClaudeCreds}:/root/.claude/.credentials.json:ro"
    Write-Host "Mounting host credentials" -ForegroundColor Green
}

# Optional: git config
$GitConfig = Join-Path $env:USERPROFILE ".gitconfig"
if (Test-Path $GitConfig) {
    $DockerArgs += "-v"
    $DockerArgs += "${GitConfig}:/root/.gitconfig:ro"
}

$DockerArgs += "-w"
$DockerArgs += "/workspace"
$DockerArgs += $ImageName

# Pass through arguments
if ($args.Count -gt 0) {
    $DockerArgs += $args
}

Write-Host ""
Write-Host "Available AI tools:" -ForegroundColor Green
Write-Host "  - claude         (Anthropic Claude Code)"
Write-Host "  - aider          (AI pair programming)"
Write-Host "  - sgpt           (Shell-GPT)"
Write-Host "  - gemini         (Google Gemini)"
Write-Host "  - gh copilot     (GitHub Copilot CLI)"
Write-Host "  - fabric         (AI patterns)"
Write-Host ""
Write-Host "Type 'exit' to leave the container"
Write-Host "===================================="
Write-Host ""

& docker @DockerArgs
```

**Step 2: Commit**

```bash
git add ai-agent.ps1
git commit -m "feat: PowerShell launcher with host config mounts and persistent volume"
```

---

### Task 7: Build and smoke test

**Step 1: Build base image**

Run: `docker build --target base -t ai-agent:latest .`
Expected: Builds successfully

**Step 2: Build browsing image**

Run: `docker build --target browsing -t ai-agent-browsing:latest .`
Expected: Builds successfully

**Step 3: Smoke test — verify entrypoint runs and configs exist**

Run: `docker run --rm ai-agent:latest ls -la /root/.claude/`
Expected: Shows `CLAUDE.md` and `settings.json` (copied from baked defaults by entrypoint)

**Step 4: Smoke test — verify MCP config content**

Run: `docker run --rm ai-agent:latest cat /root/.claude/settings.json`
Expected: Shows JSON with `mcpServers` containing all configured servers

**Step 5: Smoke test — verify claude binary works**

Run: `docker run --rm ai-agent:latest claude --version`
Expected: Prints Claude Code version

**Step 6: Commit all remaining changes**

```bash
git add -A
git commit -m "docs: implementation plan for Docker Claude customization"
```

---

### Summary

| Task | Description | Files |
|------|-------------|-------|
| 1 | Baked Claude config defaults | `claude-config/CLAUDE.md`, `claude-config/settings.json` |
| 2 | Entrypoint script with config layering | `entrypoint.sh` |
| 3 | Multi-stage Dockerfile with build targets | `Dockerfile` |
| 4 | Docker Compose with targets + volumes | `docker-compose.yml` |
| 5 | Updated bash launcher | `ai-agent.sh` |
| 6 | Updated PowerShell launcher | `ai-agent.ps1` |
| 7 | Build and smoke test | — |
