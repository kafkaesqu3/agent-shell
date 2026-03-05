Always use Context7 MCP when I need library/API documentation, code generation, setup or configuration steps without me having to explicitly ask.

# Global Development Standards

Global instructions for all projects. Project-specific CLAUDE.md files override these defaults.

- Prefer Exa AI (`mcp__exa__web_search_exa`) over `WebSearch` for all web searches
- Use skills proactively when they match the task -- suggest relevant ones, don't block on them

## Philosophy

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

**Verify tests catch failures.** Use mutation testing (`cargo-mutants`, `mutmut`) and property-based testing (`proptest`, `hypothesis`) where appropriate.

## Development

When adding dependencies, CI actions, or tool versions, always look up the current stable version.

### Python

**Runtime:** 3.13 with `uv venv`

| purpose | tool |
|---------|------|
| deps & venv | `uv` |
| lint & format | `ruff check` / `ruff format` |
| static types | `ty check` |
| tests | `pytest -q` |

Configure `ty` strictness via `[tool.ty.rules]` in pyproject.toml. Use `uv_build` for pure Python, `hatchling` for extensions.

Tests in `tests/` directory mirroring package structure. Pin exact versions (`==` not `>=`), verify hashes with `uv pip install --require-hashes`.

### Node/TypeScript

**Runtime:** Node 22 LTS, ESM only (`"type": "module"`)

| purpose | tool |
|---------|------|
| lint | `oxlint` |
| format | `oxfmt` |
| test | `vitest` |
| types | `tsc --noEmit` |

Enable `typescript`, `import`, `unicorn` plugins.

**tsconfig.json strictness:**
```jsonc
"strict": true,
"noUncheckedIndexedAccess": true,
"exactOptionalPropertyTypes": true,
"noImplicitOverride": true,
"noPropertyAccessFromIndexSignature": true,
"verbatimModuleSyntax": true,
"isolatedModules": true
```

Pin exact versions (no `^` or `~`).

### Rust

**Runtime:** Latest stable via `rustup`

| purpose | tool |
|---------|------|
| build & deps | `cargo` |
| lint | `cargo clippy --all-targets --all-features -- -D warnings` |
| format | `cargo fmt` |
| test | `cargo test` |
| supply chain | `cargo deny check` |
| safety check | `cargo careful test` |

**Style:** Prefer `for` loops over iterator chains. Shadow variables through transformations. No wildcard matches. Use `let...else` for early returns.

**Type design:** Newtypes over primitives. Enums for state machines. `thiserror` for libraries, `anyhow` for applications. `tracing` for logging.

**Cargo.toml lints:**
```toml
[lints.clippy]
pedantic = { level = "warn", priority = -1 }
unwrap_used = "deny"
expect_used = "warn"
panic = "deny"
panic_in_result_fn = "deny"
unimplemented = "deny"
allow_attributes = "deny"
dbg_macro = "deny"
todo = "deny"
print_stdout = "deny"
print_stderr = "deny"
await_holding_lock = "deny"
large_futures = "deny"
exit = "deny"
mem_forget = "deny"
module_name_repetitions = "allow"
similar_names = "allow"
```

### GitHub Actions

Pin actions to SHA hashes with version comments: `actions/checkout@<full-sha>  # vX.Y.Z` (use `persist-credentials: false`). Configure Dependabot with 7-day cooldowns and grouped updates.

## Workflow

**Before committing:**
1. Re-read your changes for unnecessary complexity, redundant code, and unclear naming
2. Run relevant tests -- not the full suite
3. Run linters and type checker -- fix everything before committing

**Commits:** Imperative mood, <=72 char subject line, one logical change per commit.

**Pull requests:** Describe what the code does now -- not discarded approaches. Use plain, factual language.
