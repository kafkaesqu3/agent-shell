###############################################################################
# Stage 1: base
###############################################################################
FROM ubuntu:24.04 AS base

ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies + Python (built into Ubuntu 24.04)
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    git \
    curl \
    wget \
    ca-certificates \
    gnupg \
    gosu \
    python3 \
    python3-venv \
    sudo \
    vim \
    jq \
    iputils-ping \
    dnsutils \
    iproute2 \
    net-tools \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 22 LTS via nodesource
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install Go 1.23.5
RUN curl -fsSL https://go.dev/dl/go1.23.5.linux-amd64.tar.gz -o go.tar.gz \
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

# Install Claude Code via official installer (npm method is deprecated)
RUN curl -fsSL https://claude.ai/install.sh | bash \
    && cp /root/.local/bin/claude /usr/local/bin/claude-real

# Wrap claude with --yolo → --dangerously-skip-permissions alias
COPY claude-config/claude-container-wrapper.sh /usr/local/bin/claude
RUN chmod +x /usr/local/bin/claude

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

# Install Python AI tools in a venv (avoids conflict with Ubuntu's system pip)
ENV VIRTUAL_ENV=/opt/venv
RUN python3 -m venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:${PATH}"

RUN pip install --no-cache-dir \
    aider-chat \
    shell-gpt \
    openai \
    anthropic \
    google-generativeai \
    google-ai-generativelanguage \
    mcp-server-fetch

# Install Fabric (AI patterns framework)
RUN go install github.com/danielmiessler/fabric/cmd/fabric@latest

# Install gopls (required by gopls-lsp Claude plugin)
RUN go install golang.org/x/tools/gopls@latest

# Set up environment
ENV SHELL=/bin/bash

# Create non-root user with passwordless sudo
RUN useradd -m -s /bin/bash agent \
    && echo "agent ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/agent \
    && chmod 0440 /etc/sudoers.d/agent

# Create config directories owned by agent
RUN mkdir -p /home/agent/.claude \
    && mkdir -p /home/agent/.config/claude \
    && mkdir -p /home/agent/.config/fabric \
    && mkdir -p /home/agent/.config/gemini \
    && mkdir -p /home/agent/.aider \
    && mkdir -p /workspace \
    && chown -R agent:agent /home/agent /workspace

# Copy config files and entrypoint
COPY claude-config/ /opt/claude-config/
COPY entrypoint.sh /opt/entrypoint.sh
RUN chmod +x /opt/entrypoint.sh

WORKDIR /workspace

ENTRYPOINT ["/opt/entrypoint.sh"]
CMD ["bash"]

###############################################################################
# Stage 2: browsing
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

# Install Python browser deps (venv inherited from base)
RUN pip install --no-cache-dir \
    playwright \
    beautifulsoup4

# Install Playwright browsers
RUN npx playwright install --with-deps chromium

ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
