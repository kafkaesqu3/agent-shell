#!/bin/bash
# AI Agent Container Launcher
# Maps current directory to /workspace and runs with layered Claude Code config

# Configuration
CLAUDE_HOME="$HOME/.claude"
IMAGE_NAME="ai-agent:latest"
VOLUME_NAME="ai-agent-claude"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Parse --env flag (must be first arg)
ENV_FILE=""
if [[ "$1" == "--env" && -n "$2" ]]; then
    ENV_FILE="$2"
    shift 2
elif [[ "$1" == --env=* ]]; then
    ENV_FILE="${1#--env=}"
    shift
fi

# Resolve .env file: --env flag > .env in current dir > .env in script dir > ~/.config/ai-agent/.env
if [ -z "$ENV_FILE" ]; then
    if [ -f ".env" ]; then
        ENV_FILE=".env"
    elif [ -f "$SCRIPT_DIR/.env" ]; then
        ENV_FILE="$SCRIPT_DIR/.env"
    elif [ -f "$HOME/.config/ai-agent/.env" ]; then
        ENV_FILE="$HOME/.config/ai-agent/.env"
    fi
fi

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
if [ -n "$ENV_FILE" ] && [ -f "$ENV_FILE" ]; then
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
    echo -e "${YELLOW}No .env file found${NC}"
    echo "  Searched: .env (current dir), $SCRIPT_DIR/.env, ~/.config/ai-agent/.env"
    echo "  Use --env <path> to specify, or copy an env template:"
    echo "    cp .env.example .env     # then fill in your keys"
    echo "    cp .env.claude .env      # Claude-only"
    echo "    cp .env.full .env        # all AI tools"
    echo "    cp .env.browsing .env    # browsing + search"
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
