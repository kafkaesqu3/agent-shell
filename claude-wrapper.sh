#!/bin/bash
# claude — wrapper that routes to the Docker container by default.
# Pass --host as the first argument to run the locally installed Claude Code instead.
#
# Installed by install.sh: real claude binary is renamed to claude-host.

if [[ "${1:-}" == "--host" ]]; then
  shift
  exec claude-host "$@"
else
  exec ai-agent claude "$@"
fi
