###############################################################################
# Stage 1: base
###############################################################################
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

# Install Go 1.23.5
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

# Install Node.js AI tools
RUN npm install -g \
    @anthropic-ai/claude-code \
    @openai/codex \
    openai \
    @google/generative-ai \
    @google/gemini-cli

# Install base MCP servers
RUN npm install -g \
    @modelcontextprotocol/server-filesystem \
    @modelcontextprotocol/server-github \
    mcp-server-sqlite-npx \
    @modelcontextprotocol/server-brave-search \
    @modelcontextprotocol/server-sequential-thinking \
    @upstash/context7-mcp

# Install Python AI tools
RUN pip3 install --no-cache-dir --break-system-packages \
    aider-chat \
    shell-gpt \
    openai \
    anthropic \
    google-generativeai \
    google-ai-generativelanguage \
    mcp-server-fetch

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

# Install browser packages
RUN apt-get update && apt-get install -y \
    chromium \
    chromium-driver \
    && rm -rf /var/lib/apt/lists/*

# Install browser MCP servers
RUN npm install -g \
    @modelcontextprotocol/server-puppeteer \
    @playwright/mcp

# Install Python browser deps
RUN pip3 install --no-cache-dir --break-system-packages \
    playwright \
    beautifulsoup4

# Install Playwright browsers
RUN npx playwright install --with-deps chromium

ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium
