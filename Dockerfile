###############################################################################
# Stage 1: lite — Claude Code only, minimal dependencies, fast build
###############################################################################
FROM ubuntu:24.04 AS lite

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    zsh \
    git \
    curl \
    wget \
    ca-certificates \
    gnupg \
    gosu \
    sudo \
    vim \
    jq \
    unzip \
    fzf \
    fd-find \
    ripgrep \
    tmux \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 22 LTS via fnm (Fast Node Manager)
ARG FNM_VERSION="1.39.0"
ENV FNM_DIR=/opt/fnm
ENV PATH="/opt/fnm:/opt/fnm/aliases/default/bin:${PATH}"
RUN curl -fsSL "https://github.com/Schniz/fnm/releases/download/v${FNM_VERSION}/fnm-linux.zip" \
    -o /tmp/fnm.zip \
    && unzip -q /tmp/fnm.zip fnm -d /opt/fnm \
    && rm /tmp/fnm.zip \
    && chmod +x /opt/fnm/fnm \
    && fnm install 22 \
    && fnm default 22

# npm supply-chain hardening: exact versions, publish-age delay, no postinstall scripts
ENV NPM_CONFIG_SAVE_EXACT=true \
    NPM_CONFIG_MINIMUM_RELEASE_AGE=1440 \
    NPM_CONFIG_AUDIT=true \
    NPM_CONFIG_IGNORE_SCRIPTS=true

# Install Claude Code via official installer
RUN curl -fsSL https://claude.ai/install.sh | bash \
    && cp /root/.local/bin/claude /usr/local/bin/claude-real

# Install ast-grep (AST-aware code search, binary installed as 'sg')
RUN npm install -g @ast-grep/cli

# Wrap claude with --yolo → --dangerously-skip-permissions alias
COPY claude-config/claude-container-wrapper.sh /usr/local/bin/claude
RUN sed -i 's/\r//' /usr/local/bin/claude && chmod +x /usr/local/bin/claude

ENV SHELL=/bin/zsh

# Create non-root user with passwordless sudo
# Ubuntu 24.04 ships with a default 'ubuntu' user at UID 1000; remove it so
# 'agent' can claim UID 1000 and the entrypoint's usermod remapping works correctly.
RUN userdel -r ubuntu 2>/dev/null || true
RUN useradd -m -u 1000 -s /bin/zsh agent \
    && echo "agent ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/agent \
    && chmod 0440 /etc/sudoers.d/agent \
    && mkdir -p /home/agent/.local/bin \
    && ln -s /usr/local/bin/claude-real /home/agent/.local/bin/claude \
    && chown -R agent:agent /home/agent/.local

# Create config directories owned by agent
RUN mkdir -p /home/agent/.claude \
    && mkdir -p /home/agent/.config/claude \
    && mkdir -p /workspace \
    && chown -R agent:agent /home/agent /workspace

# Pre-install Claude Code plugins as agent user (baked into image; named volume inherits on first run)
# Individual failures are non-fatal — marketplace availability can be transient
RUN su -s /bin/bash agent -c ' \
    HOME=/home/agent; \
    claude plugin marketplace add obra/superpowers-marketplace || echo "WARN: failed to add superpowers-marketplace (skipped)"; \
    for plugin in \
      superpowers@superpowers-marketplace \
      commit-commands@claude-plugins-official \
      hookify@claude-plugins-official \
      context7@claude-plugins-official \
      frontend-design@claude-plugins-official \
      claude-code-setup@claude-plugins-official \
      claude-md-management@claude-plugins-official \
      security-guidance@claude-plugins-official \
      code-review@claude-plugins-official; do \
      claude plugin install "$plugin" || echo "WARN: failed to install $plugin (skipped)"; \
    done \
  '

# Shell and tmux config
COPY claude-config/zshrc  /home/agent/.zshrc
COPY claude-config/tmux.conf /home/agent/.tmux.conf
RUN chown agent:agent /home/agent/.zshrc /home/agent/.tmux.conf

# Copy config files and entrypoint
# mcp-servers.json is excluded from lite — MCP packages are not installed here.
# The base stage re-adds it so the entrypoint can register servers at startup.
COPY claude-config/ /opt/claude-config/
COPY entrypoint.sh /opt/entrypoint.sh
# Strip Windows CRLF line endings so shebangs work on Linux
RUN find /opt/claude-config -name "*.sh" -exec sed -i 's/\r//' {} + \
    && sed -i 's/\r//' /opt/entrypoint.sh \
    && chmod +x /opt/entrypoint.sh /opt/claude-config/hooks/*.sh 2>/dev/null || true \
    && rm -f /opt/claude-config/mcp-servers.json

WORKDIR /workspace

ENTRYPOINT ["/opt/entrypoint.sh"]
CMD ["zsh"]

###############################################################################
# Stage 2: base — full dev environment (Go, GitHub CLI, MCP servers, AI tools)
###############################################################################
FROM lite AS base

# Additional system packages for dev tooling and diagnostics
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-venv \
    iputils-ping \
    dnsutils \
    iproute2 \
    net-tools \
    git-delta \
    && rm -rf /var/lib/apt/lists/*

# Default git config with delta pager (active when no host gitconfig is bind-mounted)
COPY claude-config/gitconfig /home/agent/.gitconfig
RUN chown agent:agent /home/agent/.gitconfig
# GIT_PAGER ensures delta is used as pager even when host gitconfig is mounted
ENV GIT_PAGER=delta

# Install Go (pinned with SHA256)
ARG GO_VERSION="1.26.1"
ARG GO_SHA256="031f088e5d955bab8657ede27ad4e3bc5b7c1ba281f05f245bcc304f327c987a"
RUN curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" -o go.tar.gz \
    && echo "${GO_SHA256}  go.tar.gz" | sha256sum --check \
    && tar -C /usr/local -xzf go.tar.gz \
    && rm go.tar.gz
ENV GOPATH=/usr/local
ENV PATH="/usr/local/go/bin:${PATH}"

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js AI tools
RUN npm install -g \
    @openai/codex \
    openai \
    @google/generative-ai \
    @google/gemini-cli

# Install base MCP servers
RUN npm install -g \
    @modelcontextprotocol/server-filesystem \
    @modelcontextprotocol/server-github \
    mcp-server-sqlite-npx \
    brave-search-mcp \
    @modelcontextprotocol/server-sequential-thinking \
    @upstash/context7-mcp

# Bake MCP server definitions — entrypoint registers them into ~/.claude.json at startup
COPY claude-config/mcp-servers.json /opt/claude-config/mcp-servers.json

# Install Python AI tools in a venv (avoids conflict with Ubuntu's system pip)
ENV VIRTUAL_ENV=/opt/venv
RUN python3 -m venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:${PATH}"

RUN pip install --no-cache-dir setuptools && \
    pip install --no-cache-dir \
    # aider-chat \
    # shell-gpt \
    # openai \
    # anthropic \
    # google-generativeai \
    # google-ai-generativelanguage \
    mcp-server-fetch \
    graphifyy

# Register graphify slash command into /opt/claude-config/commands/ so entrypoint.sh
# picks it up at startup (agent user needed because graphify install writes to ~/.claude/)
RUN su -s /bin/bash agent -c \
      'HOME=/home/agent PATH=/opt/venv/bin:${PATH} graphify install' \
    && cp /home/agent/.claude/commands/graphify.md /opt/claude-config/commands/graphify.md 2>/dev/null || true

# Install Fabric (AI patterns framework)
# RUN go install github.com/danielmiessler/fabric/cmd/fabric@v1.4.434

# Install gopls (required by gopls-lsp Claude plugin)
RUN go install golang.org/x/tools/gopls@v0.21.1

# Additional config dirs for tools added in this stage
RUN mkdir -p /home/agent/.config/fabric \
    && mkdir -p /home/agent/.config/gemini \
    && mkdir -p /home/agent/.aider \
    && chown -R agent:agent /home/agent

###############################################################################
# Stage 3: browsing — adds Chromium and browser MCP servers
###############################################################################
FROM base AS browsing

USER root

# Install browser packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    chromium-browser \
    chromium-chromedriver \
    && rm -rf /var/lib/apt/lists/*

# Install browser MCP servers
RUN npm install -g \
    @modelcontextprotocol/server-puppeteer \
    @playwright/mcp

# Add browser MCP servers to the registry (base image has non-browser servers only)
RUN jq '.mcpServers += {"puppeteer":{"command":"npx","args":["-y","@modelcontextprotocol/server-puppeteer"]},"playwright":{"command":"npx","args":["-y","@playwright/mcp","--headless"]}}' \
    /opt/claude-config/mcp-servers.json > /tmp/mcp-servers.json \
    && mv /tmp/mcp-servers.json /opt/claude-config/mcp-servers.json

# Install Python browser deps (venv inherited from base)
RUN pip install --no-cache-dir \
    playwright \
    beautifulsoup4

# Install Playwright browsers
RUN npx playwright install --with-deps chromium

ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
