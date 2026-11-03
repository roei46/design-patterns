# Server conventions (Python)

The assignment, decisions and structure are in the root `CLAUDE.md`.

## Stack
- Python 3.12, Poetry (dependencies + virtual environment).
- pytest for tests (pytest-asyncio for async code).
- Type hints everywhere, checked with `mypy --strict`. Ruff for lint/format.
- Bonus service only: FastAPI (+ whatever it needs, added when we get there).

## Per-pattern folder
Each folder under `patterns/` contains:
- the implementation (small, readable modules),
- `test_*.py` — happy path, **at least one failure scenario and one negative test**,
- `README.md` — intent, design rationale, usage example, alternatives and trade-offs, answers to the assignment's discussion questions.

## Python style for this assignment
- No `Any`. Model results and errors explicitly: frozen `@dataclass`es, `Literal` / small result unions, custom exception classes.
- Immutability where the assignment asks for it: `@dataclass(frozen=True)`, tuples instead of lists, `MappingProxyType` for read-only dicts.
- Interfaces as `typing.Protocol` (Python's version of a Swift protocol).
- Inject time-dependent things (sleep, clock) so tests are fast and exact — no real waiting in tests.
- Money as integer minor units (cents), never floats.

## Python adaptations of the TypeScript wording
- `getInstance()` → `get_instance()`; Node's module cache ≈ Python's module cache (a module-level instance is the natural singleton). Processes/workers don't share it.
- `Object.freeze` / `readonly` → frozen dataclasses, tuples, `MappingProxyType`.
- Node `heapUsed` → `tracemalloc` (and `sys.getsizeof` for rough sizes).
- Fake timers → injected `sleep` function.
- Express middleware / NestJS guards → compare to FastAPI dependencies / middleware in the READMEs.

## Commands (to fill in as we set things up)
- Run tests: `poetry run pytest`
- Type check: `poetry run mypy --strict .`

## Secrets
- Only in `.env` (git-ignored). None expected for the six patterns.
