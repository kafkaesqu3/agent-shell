FROM node:22-slim

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
    iputils-ping \
    dnsutils \
    iproute2 \
    net-tools \
    chromium \
    chromium-driver \
    && rm -rf /var/lib/apt/lists/*

# Install newer Go version
RUN curl -fsSL https://go.dev/dl/go1.23.5.linux-amd64.tar.gz -o go.tar.gz \
    && tar -C /usr/local -xzf go.tar.gz \
    && rm go.tar.gz

ENV PATH="/usr/local/go/bin:${PATH}"

# Install GitHub CLI for gh copilot integration
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

# Install MCP servers for web browsing and search
RUN npm install -g \
    @modelcontextprotocol/server-puppeteer \
    @modelcontextprotocol/server-brave-search \
    @modelcontextprotocol/server-fetch

# Install additional useful MCP servers
RUN npm install -g \
    @modelcontextprotocol/server-filesystem \
    @modelcontextprotocol/server-github \
    @modelcontextprotocol/server-sqlite

# Install Python-based AI tools
RUN pip3 install --no-cache-dir --break-system-packages \
    aider-chat \
    shell-gpt \
    openai \
    anthropic \
    google-generativeai \
    google-ai-generativelanguage

# Install Python-based MCP servers
RUN pip3 install --no-cache-dir --break-system-packages \
    mcp \
    playwright \
    beautifulsoup4 \
    requests

# Install Playwright browsers for MCP puppeteer server
RUN npx playwright install --with-deps chromium

# Install Fabric (AI patterns framework)
RUN go install github.com/danielmiessler/fabric/cmd/fabric@latest

# Set up environment
ENV PATH="/root/go/bin:${PATH}"
ENV SHELL=/bin/bash
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium

# Create config directories
RUN mkdir -p /root/.claude \
    && mkdir -p /root/.config/claude \
    && mkdir -p /root/.config/fabric \
    && mkdir -p /root/.config/gemini \
    && mkdir -p /root/.aider \
    && mkdir -p /root/.config/mcp

# Create MCP server configuration
RUN echo '{\n\
  "mcpServers": {\n\
    "puppeteer": {\n\
      "command": "npx",\n\
      "args": ["-y", "@modelcontextprotocol/server-puppeteer"]\n\
    },\n\
    "brave-search": {\n\
      "command": "npx",\n\
      "args": ["-y", "@modelcontextprotocol/server-brave-search"],\n\
      "env": {\n\
        "BRAVE_API_KEY": ""\n\
      }\n\
    },\n\
    "fetch": {\n\
      "command": "npx",\n\
      "args": ["-y", "@modelcontextprotocol/server-fetch"]\n\
    },\n\
    "filesystem": {\n\
      "command": "npx",\n\
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/workspace"]\n\
    },\n\
    "github": {\n\
      "command": "npx",\n\
      "args": ["-y", "@modelcontextprotocol/server-github"],\n\
      "env": {\n\
        "GITHUB_PERSONAL_ACCESS_TOKEN": ""\n\
      }\n\
    }\n\
  }\n\
}' > /root/.config/mcp/config.json

# Default working directory
WORKDIR /workspace

# Default command
CMD [ "bash" ]