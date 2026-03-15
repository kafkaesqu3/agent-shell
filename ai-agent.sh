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
USE_RM=false
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
    elif [[ "$1" == "--rm" ]]; then
        USE_RM=true
        shift
    elif [[ "$1" == "--lite" ]]; then
        IMAGE_NAME="ai-agent:lite"
        shift
    elif [[ "$1" == "--browsing" ]]; then
        IMAGE_NAME="ai-agent:browsing"
        shift
    else
        break
    fi
done

# Handle subcommands
if [[ "${1:-}" == "sync" ]]; then
    if [ -z "$CONTAINER_NAME" ]; then
        CONTAINER_NAME="$(basename "$(pwd)")"
    fi
    if ! docker info > /dev/null 2>&1; then
        echo -e "${RED}Docker is not running!${NC}"; exit 1
    fi
    mkdir -p "$HOME/.claude/projects"
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$" 2>/dev/null; then
        echo -e "${BLUE}Syncing from running container: $CONTAINER_NAME${NC}"
    elif docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$" 2>/dev/null; then
        echo -e "${BLUE}Syncing from stopped container: $CONTAINER_NAME${NC}"
    else
        echo -e "${RED}Container not found: $CONTAINER_NAME${NC}"
        echo "Specify with --name, or run from the project directory (container is named after the directory)"
        exit 1
    fi
    docker cp "${CONTAINER_NAME}:/home/agent/.claude/projects/." "$HOME/.claude/projects/" 2>/dev/null || true
    echo -e "${GREEN}Session logs synced to ~/.claude/projects/${NC}"
    exit 0
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

# Build docker run command as an array (safe word-splitting, no eval)
DOCKER_ARGS=("docker" "run" "-it")
if [ "$USE_RM" = true ]; then
    DOCKER_ARGS+=("--rm")
else
    if [ -z "$CONTAINER_NAME" ]; then
        CONTAINER_NAME="$(basename "$(pwd)")"
    fi
    DOCKER_ARGS+=("--name" "$CONTAINER_NAME")
fi

# Parse .env and pass each var as -e KEY=VAL
if [ -n "$ENV_FILE" ] && [ -f "$ENV_FILE" ]; then
    echo -e "${GREEN}Loading API keys from: $ENV_FILE${NC}"
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" || "$line" == \#* ]] && continue  # skip blanks and comments
        line="${line#export }"                            # strip optional 'export '
        [[ "$line" == *=* ]] && DOCKER_ARGS+=("-e" "$line")
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

# Volumes
DOCKER_ARGS+=("-v" "$(pwd):/workspace")
DOCKER_ARGS+=("-v" "$VOLUME_NAME:/home/agent/.claude")

# Optional: host CLAUDE.md override (staged for entrypoint processing)
if [ -f "$CLAUDE_HOME/CLAUDE.md" ]; then
    DOCKER_ARGS+=("-v" "$CLAUDE_HOME/CLAUDE.md:/opt/host-config/CLAUDE.md:ro")
    echo -e "${GREEN}Mounting host CLAUDE.md${NC}"
fi

# Optional: host settings.json override
if [ -f "$CLAUDE_HOME/settings.json" ]; then
    DOCKER_ARGS+=("-v" "$CLAUDE_HOME/settings.json:/opt/host-config/settings.json:ro")
    echo -e "${GREEN}Mounting host settings.json${NC}"
fi

# Optional: host credentials — staged outside the named volume so the
# entrypoint can copy them in (bind-mounting a file inside a named-volume
# directory is unreliable; the volume wins).
if [ -f "$CLAUDE_HOME/.credentials.json" ]; then
    DOCKER_ARGS+=("-v" "$CLAUDE_HOME/.credentials.json:/opt/host-config/.credentials.json:ro")
    echo -e "${GREEN}Mounting host credentials${NC}"
fi

# Optional: git config
if [ -f "$HOME/.gitconfig" ]; then
    DOCKER_ARGS+=("-v" "$HOME/.gitconfig:/home/agent/.gitconfig:ro")
fi

[ -n "$SKILL_PROFILES" ] && DOCKER_ARGS+=("-e" "SKILL_PROFILES=$SKILL_PROFILES")
DOCKER_ARGS+=("-e" "HOST_UID=$(id -u)" "-e" "HOST_GID=$(id -g)")
DOCKER_ARGS+=("-w" "/workspace")
DOCKER_ARGS+=("$IMAGE_NAME")

# Pass through any remaining arguments
if [ $# -gt 0 ]; then
    DOCKER_ARGS+=("$@")
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

"${DOCKER_ARGS[@]}"
