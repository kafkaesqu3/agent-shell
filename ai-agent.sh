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

# Parse flags
ENV_FILE=""
CONTAINER_NAME=""
SKILL_PROFILES=""
while true; do
    if [[ "$1" == "--env" && -n "$2" ]]; then
        ENV_FILE="$2"
        shift 2
    elif [[ "$1" == --env=* ]]; then
        ENV_FILE="${1#--env=}"
        shift
    elif [[ "$1" == "--name" && -n "$2" ]]; then
        CONTAINER_NAME="$2"
        shift 2
    elif [[ "$1" == --name=* ]]; then
        CONTAINER_NAME="${1#--name=}"
        shift
    elif [[ "$1" == "--skills" && -n "$2" ]]; then
        SKILL_PROFILES="$2"
        shift 2
    elif [[ "$1" == --skills=* ]]; then
        SKILL_PROFILES="${1#--skills=}"
        shift
    else
        break
    fi
done

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
if [ -n "$CONTAINER_NAME" ]; then
    DOCKER_CMD="docker run -it --name $CONTAINER_NAME"
else
    DOCKER_CMD="docker run -it --rm"
fi

# Parse .env and pass each var as -e KEY=VAL
if [ -n "$ENV_FILE" ] && [ -f "$ENV_FILE" ]; then
    echo -e "${GREEN}Loading API keys from: $ENV_FILE${NC}"
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" || "$line" == \#* ]] && continue  # skip blanks and comments
        line="${line#export }"                            # strip optional 'export '
        [[ "$line" == *=* ]] && DOCKER_CMD="$DOCKER_CMD -e $line"
    done < "$ENV_FILE"
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
DOCKER_CMD="$DOCKER_CMD -v $VOLUME_NAME:/home/agent/.claude"

# Optional: host CLAUDE.md override (staged for entrypoint processing)
if [ -f "$CLAUDE_HOME/CLAUDE.md" ]; then
    DOCKER_CMD="$DOCKER_CMD -v $CLAUDE_HOME/CLAUDE.md:/opt/host-config/CLAUDE.md:ro"
    echo -e "${GREEN}Mounting host CLAUDE.md${NC}"
fi

# Optional: host settings.json override (mounted outside the volume for entrypoint processing)
if [ -f "$CLAUDE_HOME/settings.json" ]; then
    DOCKER_CMD="$DOCKER_CMD -v $CLAUDE_HOME/settings.json:/opt/host-config/settings.json:ro"
    echo -e "${GREEN}Mounting host settings.json${NC}"
fi

# Optional: host credentials — staged outside the named volume so the
# entrypoint can copy them in (bind-mounting a file inside a named-volume
# directory is unreliable; the volume wins).
if [ -f "$CLAUDE_HOME/.credentials.json" ]; then
    DOCKER_CMD="$DOCKER_CMD -v $CLAUDE_HOME/.credentials.json:/opt/host-config/.credentials.json:ro"
    echo -e "${GREEN}Mounting host credentials${NC}"
fi

# Optional: git config
if [ -f "$HOME/.gitconfig" ]; then
    DOCKER_CMD="$DOCKER_CMD -v $HOME/.gitconfig:/home/agent/.gitconfig:ro"
fi

[ -n "$SKILL_PROFILES" ] && DOCKER_CMD="$DOCKER_CMD -e SKILL_PROFILES=$SKILL_PROFILES"

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
