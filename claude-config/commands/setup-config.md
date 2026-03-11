You are installing or updating the agent-shell Claude Code configuration
into the user's `~/.claude/` directory.

## Source files

The config files are in the `claude-config/` directory of this repo.
If the repo is not cloned locally, fetch from GitHub:

```
https://raw.githubusercontent.com/YOUR_ORG/agent-shell/main/claude-config/
```

Files to install:
- `settings.json`
- `CLAUDE.md`
- `statusline.sh`
- `commands/review-pr.md`
- `commands/merge-dependabot.md`
- `commands/fix-issue.md`

## Steps

1. **Inventory what exists.** Read `~/.claude/settings.json`,
   `~/.claude/CLAUDE.md`, `~/.claude/statusline.sh`, and check for
   command files under `~/.claude/commands/`. Note which files exist
   and which don't.

2. **Ask the user what to install.** Use AskUserQuestion with a
   single multi-select question. List each component with a short
   description. Pre-label components that are missing from
   `~/.claude/` as recommended. Components:
   - **settings.json** -- permissions, hooks, telemetry, statusline,
     MCP servers, plugins
   - **CLAUDE.md** -- global development standards and tool
     preferences
   - **Statusline script** -- two-line status bar with context/cost
     tracking
   - **review-pr command** -- multi-agent PR review workflow
   - **merge-dependabot command** -- automated dependabot PR
     evaluation and merge
   - **fix-issue command** -- end-to-end issue fixing workflow

3. **For each selected component, install it:**

   - **settings.json**: If `~/.claude/settings.json` doesn't exist,
     write it directly. If it does exist, read both files and merge
     the repo's keys into the existing file -- preserve any user
     keys that don't conflict. Show the user the merged result and
     ask for confirmation before writing.

   - **CLAUDE.md**: If `~/.claude/CLAUDE.md` doesn't exist, write
     it directly. If it already exists, tell the user it exists and
     ask whether to overwrite, skip, or show a diff. Never silently
     overwrite CLAUDE.md -- it likely has personal customizations.

   - **Statusline script**: Write to `~/.claude/statusline.sh` and
     `chmod +x` it. Safe to overwrite -- no user customization.

   - **Commands**: Write to `~/.claude/commands/review-pr.md`,
     `~/.claude/commands/merge-dependabot.md`, and/or
     `~/.claude/commands/fix-issue.md`. Create the directory if
     needed. Safe to overwrite.

4. **Post-install.** Summarize what was installed/updated. If
   CLAUDE.md was installed, suggest they review and customize it.
   Note that MCP server env var placeholders (like
   `__GITHUB_TOKEN__`) need to be replaced with real values.
