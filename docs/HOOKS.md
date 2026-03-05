# Claude Code Hooks

Hooks enforce development standards automatically. When a hook blocks an action, Claude receives the error message and adjusts — no CLAUDE.md instruction needed.

Configured in `claude-config/settings.json`. Script-based hooks live in `claude-config/hooks/` and are copied to `~/.claude/hooks/` by the container entrypoint.

## PreToolUse: Bash

These block shell commands before execution. All are inline in `settings.json`.

| # | Blocked pattern | Error message | Replaces |
|---|----------------|---------------|----------|
| 1 | `rm -rf`, `rm -fr` (recursive + force) | Use trash instead of rm -rf | CLI tools table guidance |
| 2 | `git push` to main/master | Use feature branches, not direct push to main | Workflow commit rules |
| 3 | `pip install`, `pip3 install`, `poetry install/add/remove/update` | Use uv instead of pip/poetry | Python tooling section |
| 4 | `black`, `pylint`, `flake8`, `mypy`, `pyright` | Use ruff instead of black/pylint/flake8 / Use ty instead of mypy/pyright | Python tooling section |
| 5 | `eslint`, `prettier` | Use oxlint/oxfmt instead of eslint/prettier | Node/TypeScript tooling section |
| 6 | `grep`, `find` | Use rg (ripgrep) instead of grep / Use fd instead of find | CLI tools table guidance |
| 7 | `git add` with `.env`, `.pem`, `.key`, `.secret`, `credentials` | Do not stage secret files | Workflow commit rules |

### Detection pattern

Each hook extracts the command via `jq -r '.tool_input.command'` and matches against regex patterns that account for command chaining (`; && || |`).

## PreToolUse: Write / Edit

These block file writes before they happen. Uses the external script `hooks/check-imports.sh`.

| # | Check | Error message | Replaces |
|---|-------|---------------|----------|
| 8 | Relative imports (`from ..` in Python, `from '../` in JS/TS) | Use absolute imports, not relative (..) imports | Code quality hard limits |

### How it works

The script reads the tool input JSON from stdin, extracts `file_path` and either `content` (Write) or `new_string` (Edit), then checks for relative import patterns based on file extension.

## PostToolUse: Write / Edit

These run after a file is written and produce warnings (non-blocking). Uses the external script `hooks/post-write-lint.sh`.

| # | Check | Output | Replaces |
|---|-------|--------|----------|
| 9 | `.sh` files missing `set -euo pipefail` in first 5 lines | WARNING: missing 'set -euo pipefail' near the top | Bash section guidance |
| 10 | `.sh` files: runs `shellcheck` (if installed) | shellcheck findings | Bash section lint instructions |
| 11 | `.github/workflows/*.yml` files: runs `actionlint` (if installed) | actionlint findings | GitHub Actions section |

## Adding a new hook

### Inline (simple pattern match)

Add to the `hooks` array under the appropriate matcher in `settings.json`:

```json
{
  "type": "command",
  "command": "CMD=$(jq -r '.tool_input.command'); if echo \"$CMD\" | grep -qE 'PATTERN'; then echo 'BLOCKED: message' >&2; exit 2; fi"
}
```

### Script-based (complex logic)

1. Create a script in `claude-config/hooks/`
2. Read JSON from stdin, extract fields with `jq`
3. Exit 2 to block (PreToolUse) or exit 0 after printing warnings (PostToolUse)
4. Reference it in `settings.json`: `"command": "~/.claude/hooks/your-script.sh"`

### Exit codes

| Code | Meaning |
|------|---------|
| 0 | Allow (PreToolUse) or success (PostToolUse) |
| 2 | Block the action (PreToolUse only) |

### Input format

Hooks receive JSON on stdin:

```json
{
  "tool_name": "Bash|Write|Edit",
  "tool_input": {
    "command": "...",
    "file_path": "...",
    "content": "...",
    "old_string": "...",
    "new_string": "..."
  }
}
```

Fields vary by tool. Use `jq -r '.tool_input.FIELD // empty'` for safe extraction.
