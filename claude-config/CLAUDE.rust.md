# Rust Standards

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
