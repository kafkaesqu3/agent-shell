---
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git reset:*), Bash(git commit:*)
description: Squash checkpoint commits and create a clean commit with a proper message
---

## Context

- Current branch: !`git branch --show-current`
- Recent commits: !`git log --oneline -20`
- Checkpoint commits to squash: !`git log --oneline --reverse $(git log --oneline | awk '/^[a-f0-9]+ claude: session checkpoint/{print $1}' | tail -1)^..HEAD 2>/dev/null | grep -v "claude: session checkpoint" | head -1 || echo "none"`

## Your task

1. Find the base commit — the most recent commit that is NOT a `claude: session checkpoint` message. Use `git log --oneline` to identify it.

2. If there are one or more `claude: session checkpoint` commits on top of that base:
   - Run `git add -A` to stage any unstaged changes
   - Run `git reset --soft <base-sha>` to collapse all checkpoint commits into the index
   - Run `git diff --cached --stat` to see what's staged

3. If there are no checkpoint commits, just stage any unstaged changes with `git add -A`.

4. Run `git diff --cached` (limit output mentally to understand the changes) and write a commit message:
   - Subject line: imperative mood, max 72 chars, describes what changed at a high level
   - No body needed unless the change is complex

5. Create the commit with that message.

Do not output explanatory text. Only make the tool calls needed to complete the commit.
