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

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }   # $* intentional: joins multi-word messages
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }    # callers always pass simple string literals
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*"; }

cmd_exists() { command -v "$1" &>/dev/null; }

# Portable in-place sed: BSD sed (macOS) requires an explicit empty extension with -i.
sed_i() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "$@"
  else
    sed -i "$@"
  fi
}

detect_os() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "macos"
  elif [[ "$OSTYPE" == linux* ]]; then
    if cmd_exists apt-get;                    then echo "ubuntu"
    elif cmd_exists dnf || cmd_exists yum;    then echo "fedora"
    elif cmd_exists pacman;                   then echo "arch"
    else                                           echo "linux"
    fi
  else
    echo "unknown"
  fi
}
