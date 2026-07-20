# Area: scripts — the deterministic engine behind the house-rules skill

> See @AGENTS.md at the repo root for repo-wide rules.

## Shape

Two bash scripts, no LLM, sharing one convention: `#!/usr/bin/env bash`, a header comment (usage, subcommands or purpose, tuning env vars), then `set -euo pipefail`. Each resolves the target repo via `git rev-parse --show-toplevel` (erroring if absent) and reads/writes persistent state at `.claude/house-rules.lock.json` there. Any JSON work goes through `python3` (heredoc or `-c`), inputs passed via env vars or argv — never jq or `mapfile` (stock macOS ships bash 3.2, no jq). `staleness.sh` is the engine: a `case "${1:-}" in write|check|hash|discover|ignore)` dispatcher over five subcommands. `staleness-backfill.sh` is a thin sibling: it self-locates `staleness.sh` via `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` and calls `staleness.sh write <dir>` for every area doc (`AGENTS.md`/`CLAUDE.md`) missing a manifest baseline.

## Reference

`@./staleness.sh` — the actual engine; every other script (and `/house-rules` itself) is a thin caller around its five subcommands.

## Adding one more

1. Name it for what it does; `set -euo pipefail`, a header comment stating usage/purpose, self-locate via `SCRIPT_DIR` if it needs a sibling.
2. Resolve the target repo with `git rev-parse --show-toplevel`; never assume the working directory.
3. Read/write persistent state only at `.claude/house-rules.lock.json`, and only through `staleness.sh`'s existing subcommands (`write`/`ignore`) — never hand-edit the JSON.
4. Do any JSON work in a `python3` heredoc or `-c` snippet, never jq or `mapfile`.
5. Exit 2 only for bad usage; 1 for a real finding/error; 0 for success.

## Tripwires

- Never write `.claude/house-rules.lock.json` by hand — always through `staleness.sh write`/`ignore`, so the hashing algorithm stays in one place.
- Never use jq or `mapfile`: stock macOS lacks jq and ships bash 3.2.

<!-- Maintained by /house-rules. Pattern changed? Run: /house-rules skills/house-rules/scripts -->
