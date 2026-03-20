#!/bin/bash
# claude — single entry point. All routing (host/Docker, profiles, --yolo) is
# handled by ai-agent. This wrapper exists so the binary at the claude PATH
# location delegates to ai-agent in non-interactive contexts (scripts, IDEs).
exec ai-agent "$@"
