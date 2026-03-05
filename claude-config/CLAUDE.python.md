# Python Standards

**Runtime:** 3.13 with `uv venv`

| purpose | tool |
|---------|------|
| deps & venv | `uv` |
| lint & format | `ruff check` / `ruff format` |
| static types | `ty check` |
| tests | `pytest -q` |

Configure `ty` strictness via `[tool.ty.rules]` in pyproject.toml. Use `uv_build` for pure Python, `hatchling` for extensions.

Tests in `tests/` directory mirroring package structure. Pin exact versions (`==` not `>=`), verify hashes with `uv pip install --require-hashes`.
