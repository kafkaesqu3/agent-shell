#!/usr/bin/env bash
# Shared constants and helpers — sourced by install.sh and all install/* modules.
# Not independently runnable.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/ai-agent}"
LOCAL_BIN="${LOCAL_BIN:-$HOME/.local/bin}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()   { echo -e "${RED}[ERROR]${NC} $1"; }

cmd_exists() { command -v "$1" &>/dev/null; }

detect_os() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "macos"
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if cmd_exists apt-get;                    then echo "ubuntu"
    elif cmd_exists dnf || cmd_exists yum;    then echo "fedora"
    elif cmd_exists pacman;                   then echo "arch"
    else                                           echo "linux"
    fi
  else
    echo "unknown"
  fi
}
