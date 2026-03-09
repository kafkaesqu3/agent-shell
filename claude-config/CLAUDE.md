# Global Development Standards

Global instructions for all projects. Project-specific CLAUDE.md files override these defaults.

Language-specific standards: see CLAUDE.python.md, CLAUDE.node.md, CLAUDE.rust.md (loaded automatically when those languages are detected in the project).

- Prefer Exa AI (`mcp__exa__web_search_exa`) over `WebSearch` for all web searches
- Use skills proactively when they match the task -- suggest relevant ones, don't block on them

## Philosophy
- **Chain of thought** - think step by step on how to execute every task. 
- **No speculative features** - Don't add features, flags, or configuration unless users actively need them
- **No premature abstraction** - Don't create utilities until you've written the same code three times
- **Clarity over cleverness** - Prefer explicit, readable code over dense one-liners
- **Root cause before suggesting fix** - Always perform a root cause analysis before suggesting a fix for an error or bug
- **Justify new dependencies** - Each dependency is attack surface and maintenance burden
- **No phantom features** - Don't document or validate features that aren't implemented
- **Replace, don't deprecate** - When a new implementation replaces an old one, remove the old one entirely
- **Verify at every level** - Prefer structure-aware tools (ast-grep, LSPs, compilers) over text pattern matching
- **Bias toward action** - Decide and move for anything easily reversed; ask before committing to interfaces, data models, or architecture
- **Finish the job** - Handle the edge cases you can see. Clean up what you touched. Don't invent new scope.
- **Agent-native by default** - Design so agents can achieve any outcome users can

## Code Quality

### Hard limits

1. <=100 lines/function, cyclomatic complexity <=8
2. <=5 positional params
3. 100-char line length
4. Google-style docstrings on non-trivial public APIs

### Zero warnings policy

Fix every warning from every tool. If a warning truly can't be fixed, add an inline ignore with a justification comment.

### Error handling

- Fail fast with clear, actionable messages
- Never swallow exceptions silently
- Include context (what operation, what input, suggested fix)

### Reviewing code

Evaluate in order: architecture -> code quality -> tests -> performance. Before reviewing, sync to latest remote (`git fetch origin`).

### Testing

**Test behavior, not implementation.** If a refactor breaks your tests but not your code, the tests were wrong.

**Test edges and errors, not just the happy path.** Empty inputs, boundaries, malformed data, missing files, network failures.

**Mock boundaries, not logic.** Only mock things that are slow, non-deterministic, or external services you don't control.

**Verify tests catch failures.** Use mutation testing and property-based testing where appropriate.

## Development

When adding dependencies, CI actions, or tool versions, always look up the current stable version.

### GitHub Actions

Pin actions to SHA hashes with version comments: `actions/checkout@<full-sha>  # vX.Y.Z` (use `persist-credentials: false`). Configure Dependabot with 7-day cooldowns and grouped updates.

## Research Tools
 Use BrightData MCP as the primary tool for all web research tasks. Prefer BrightData over `brave_web_search` and `WebFetch` because:
  | Task | Tool |
  |------|------|
  | Search / discovery | `mcp__brightdata__search_engine` |
  | Scrape a single page | `mcp__brightdata__scrape_as_markdown` |
  | Scrape multiple pages | `mcp__brightdata__scrape_batch` |
  | Batch searches | `mcp__brightdata__search_engine_batch` |
  
Always use Context7 MCP when I need library/API documentation, code generation, setup or configuration steps without me having to explicitly ask.

## Workflow

**Before committing:**
1. Re-read your changes for unnecessary complexity, redundant code, and unclear naming
2. Run relevant tests -- not the full suite
3. Run linters and type checker -- fix everything before committing

**Commits:** Imperative mood, <=72 char subject line, one logical change per commit.

**Pull requests:** Describe what the code does now -- not discarded approaches. Use plain, factual language.

