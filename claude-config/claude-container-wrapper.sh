#!/usr/bin/env bash
# Wrapper around the real claude binary — translates --yolo to
# --dangerously-skip-permissions so muscle memory works inside the container.
set -euo pipefail

args=()
for arg in "$@"; do
  [[ "$arg" == "--yolo" ]] && args+=("--dangerously-skip-permissions") || args+=("$arg")
done

exec claude-real "${args[@]+"${args[@]}"}"
