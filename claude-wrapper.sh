#!/bin/bash
# claude — wrapper that routes to the Docker container by default.
# Pass --host as the first argument to run the locally installed Claude Code instead.
# Pass --yolo as an argument to enable --dangerously-skip-permissions.
#
# Installed by install.sh: real claude binary is renamed to claude-host.

# Translate --yolo → --dangerously-skip-permissions
args=()
for arg in "$@"; do
  [[ "$arg" == "--yolo" ]] && args+=("--dangerously-skip-permissions") || args+=("$arg")
done
set -- "${args[@]+"${args[@]}"}"

if [[ "${1:-}" == "--host" ]]; then
  shift
  exec claude-host "$@"
else
  exec ai-agent claude "$@"
fi
