#!/bin/bash
# AI Agent Container Launcher
# Maps current directory to /workspace and runs with layered Claude Code config

# Configuration
CLAUDE_HOME="$HOME/.claude"
IMAGE_NAME="ai-agent:latest"
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
    cat <<EOF
Usage: ai-agent.sh [OPTIONS] [SUBCOMMAND]

Launch an AI agent Docker container with the current directory mounted as /workspace.

Options:
  --env <path>        Path to .env file (default: auto-detected)
  --name <name>       Container name (default: current directory name)
  --skills <profiles> Comma-separated skill profiles to activate
  --rm                Remove container on exit (ephemeral mode)
  --lite              Use ai-agent:lite image (Claude Code only)
  --browsing          Use ai-agent:browsing image (base + Chromium)
  --work               Load .env.work profile (Databricks / work credentials)
  --local [MODEL]      Load .env.local profile; optionally set CLAUDE_MODEL=MODEL
  --host              Run on this machine instead of Docker (still applies env/profile)
  --yolo              Enable --dangerously-skip-permissions (passed through to claude)
  -h, --help          Show this help message

.env resolution order:
  1. --env flag
  2. .env in current directory
  3. .env in script directory
  4. ~/.config/ai-agent/.env

Examples:
  ai-agent.sh                        # launch with auto-detected .env
  ai-agent.sh --env ~/.env.work      # use specific env file
  ai-agent.sh --browsing --rm        # ephemeral browsing container
EOF
}

# Parse flags
ENV_FILE=""
CONTAINER_NAME=""
SKILL_PROFILES=""
USE_RM=false
PROFILE=""
CLAUDE_MODEL=""
HOST_MODE=false
while true; do
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        usage; exit 0
    elif [[ "$1" == "--env" && -n "$2" ]]; then
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
    elif [[ "$1" == "--work" ]]; then
        PROFILE="work"
        shift
    elif [[ "$1" == "--local" ]]; then
        PROFILE="local"
        if [[ "${2:-}" != --* && -n "${2:-}" ]]; then
            CLAUDE_MODEL="$2"
            shift
        fi
        shift
    elif [[ "$1" == "--host" ]]; then
        HOST_MODE=true
        shift
    else
        break
    fi
done

# Translate --yolo in passthrough args
INVOKED_AS="$(basename "$0")"
_translated=()
for _a in "$@"; do
    [[ "$_a" == "--yolo" ]] && _translated+=("--dangerously-skip-permissions") || _translated+=("$_a")
done
set -- "${_translated[@]+"${_translated[@]}"}"

# When invoked as 'claude', inject 'claude' as the container command so that
# 'claude foo' maps to 'docker run ... claude foo' inside the container.
# Skip injection in host mode — no container command is needed.
if [[ "$INVOKED_AS" == "claude" && "$HOST_MODE" != true ]]; then
    set -- claude "$@"
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

# Resolve profile env file: CWD > script dir > ~/.config/ai-agent/
PROFILE_ENV=""
if [ -n "$PROFILE" ]; then
    for dir in "$(pwd)" "$SCRIPT_DIR" "$HOME/.config/ai-agent"; do
        if [ -f "$dir/.env.$PROFILE" ]; then
            PROFILE_ENV="$dir/.env.$PROFILE"
            break
        fi
    done
    if [ -z "$PROFILE_ENV" ]; then
        echo -e "${YELLOW}Warning: no .env.$PROFILE found (searched CWD, script dir, ~/.config/ai-agent/)${NC}"
    fi
fi

# --- Host mode: source env files on the host and exec the local claude binary ---
if [[ "$HOST_MODE" == true ]]; then
    if ! command -v claude-host &>/dev/null; then
        echo -e "${RED}claude-host not found — run install.sh --path to set up${NC}"
        exit 1
    fi
    if [[ -n "$ENV_FILE" && -f "$ENV_FILE" ]]; then
        set -o allexport
        # shellcheck source=/dev/null
        source "$ENV_FILE"
        set +o allexport
    fi
    if [[ -f "$PROFILE_ENV" ]]; then
        set -o allexport
        # shellcheck source=/dev/null
        source "$PROFILE_ENV"
        set +o allexport
    fi
    if [[ -n "$CLAUDE_MODEL" ]]; then
        exec claude-host --model "$CLAUDE_MODEL" "$@"
    else
        exec claude-host "$@"
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
    echo -e "${YELLOW}Mode: ephemeral (--rm)${NC}"
else
    if [ -z "$CONTAINER_NAME" ]; then
        CONTAINER_NAME="$(basename "$(pwd)")"
    fi
    echo -e "${BLUE}Container name: $CONTAINER_NAME${NC}"

    # If container already exists, exec into it instead of creating a new one
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$" 2>/dev/null; then
        echo -e "${YELLOW}Reusing existing container: $CONTAINER_NAME${NC}"
        # Start it if stopped
        if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$" 2>/dev/null; then
            if ! docker start "$CONTAINER_NAME" > /dev/null 2>&1; then
                echo -e "${YELLOW}Stopped container could not be restarted (stale mounts?), removing and recreating...${NC}"
                docker rm "$CONTAINER_NAME" > /dev/null
                # Fall through to docker run below
            else
                if [ $# -gt 0 ]; then
                    exec docker exec -it -u agent "$CONTAINER_NAME" "$@"
                else
                    exec docker exec -it -u agent "$CONTAINER_NAME" /bin/bash
                fi
            fi
        else
            if [ $# -gt 0 ]; then
                exec docker exec -it -u agent "$CONTAINER_NAME" "$@"
            else
                exec docker exec -it -u agent "$CONTAINER_NAME" /bin/bash
            fi
        fi
    fi

    DOCKER_ARGS+=("--name" "$CONTAINER_NAME")
fi

# Parse .env and pass each var as -e KEY=VAL
if [ -n "$ENV_FILE" ] && [ -f "$ENV_FILE" ]; then
    echo -e "${GREEN}Loading API keys from: $ENV_FILE${NC}"
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" || "$line" == \#* ]] && continue  # skip blanks and comments
        line="${line#export }"                            # strip optional 'export '
        [[ "$line" == *=* ]] || continue
        key="${line%%=*}"
        val="${line#*=}"
        val="${val#\"}" val="${val%\"}"                  # strip surrounding double-quotes
        val="${val#\'}" val="${val%\'}"                  # strip surrounding single-quotes
        DOCKER_ARGS+=("-e" "$key=$val")
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

# Load profile env (overrides base vars)
if [ -f "$PROFILE_ENV" ]; then
    echo -e "${GREEN}Loading profile from: $PROFILE_ENV${NC}"
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line#export }"
        [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] || continue
        key="${line%%=*}"
        val="${line#*=}"
        val="${val#\"}" val="${val%\"}"                  # strip surrounding double-quotes
        val="${val#\'}" val="${val%\'}"                  # strip surrounding single-quotes
        DOCKER_ARGS+=("-e" "$key=$val")
    done < "$PROFILE_ENV"
fi
[ -n "$CLAUDE_MODEL" ] && DOCKER_ARGS+=("-e" "CLAUDE_MODEL=$CLAUDE_MODEL")

echo ""

# Volumes
mkdir -p "$(pwd)/.agent"
DOCKER_ARGS+=("-v" "$(pwd):/workspace")
DOCKER_ARGS+=("-v" "$(pwd)/.agent:/home/agent/.claude")

# Optional: host credentials
if [ -f "$CLAUDE_HOME/.credentials.json" ]; then
    DOCKER_ARGS+=("-v" "$CLAUDE_HOME/.credentials.json:/opt/host-config/.credentials.json:ro")
    echo -e "${GREEN}Mounting host credentials${NC}"
fi

# Optional: git config
if [ -f "$HOME/.gitconfig" ]; then
    DOCKER_ARGS+=("-v" "$HOME/.gitconfig:/home/agent/.gitconfig:ro")
fi

[ -n "$SKILL_PROFILES" ] && DOCKER_ARGS+=("-e" "SKILL_PROFILES=$SKILL_PROFILES")
# Use workspace directory owner's UID/GID so the remapped agent user can write
# to /workspace even when the script runner differs from the directory owner.
DOCKER_ARGS+=("-e" "HOST_UID=$(stat -c %u .)" "-e" "HOST_GID=$(stat -c %g .)")
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
