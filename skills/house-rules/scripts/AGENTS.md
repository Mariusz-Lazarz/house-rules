# Area: scripts — the deterministic engine behind the house-rules skill

> See @AGENTS.md at the repo root for repo-wide rules.

## Purpose

The non-LLM backbone the skill delegates to: `SKILL.md` calls `staleness.sh`
for every hash/write/discover/ignore operation, `tests/*.test.sh` invoke both
scripts directly, and `docs/how-it-works.md` documents `staleness.sh
check`/`discover` as the recipe users wire into their own pre-push hook or CI.

## What's here

Two bash scripts, distinct roles. `staleness.sh` is the engine: a `case
"${1:-}" in write|check|hash|discover|ignore)` dispatcher, resolving the
target repo via `git rev-parse --show-toplevel` and reading/writing
`.claude/house-rules.lock.json` there. `staleness-backfill.sh` is a thin
sibling — self-locates `staleness.sh` via `SCRIPT_DIR="$(cd "$(dirname
"${BASH_SOURCE[0]}")" && pwd)"` and calls `staleness.sh write <dir>` for
every area doc missing a baseline. Both share one convention: header comment,
`set -euo pipefail`, JSON only through `python3` (heredoc or `-c`) — never
jq or `mapfile` (stock macOS ships bash 3.2, no jq).

## Reference

`@./staleness.sh` — the actual engine; `staleness-backfill.sh` (and
`/house-rules` itself) is a thin caller around its five subcommands.

## Extending

1. Name it for what it does; header comment, `set -euo pipefail`, self-locate
   via `SCRIPT_DIR` if it needs a sibling.
2. Resolve the target repo with `git rev-parse --show-toplevel`; never assume
   the working directory.
3. Read/write state only at `.claude/house-rules.lock.json`, only through
   `staleness.sh`'s existing subcommands — never hand-edit the JSON.
4. Do JSON work in a `python3` heredoc or `-c` snippet, never jq or `mapfile`.
5. Exit 2 for bad usage, 1 for a real finding/error, 0 for success.

## Tripwires

- Never write `.claude/house-rules.lock.json` by hand — always through
  `staleness.sh write`/`ignore`, so the hashing algorithm stays in one place.
- Never use jq or `mapfile`: stock macOS lacks jq and ships bash 3.2.

<!-- Maintained by /house-rules. Pattern changed? Run: /house-rules skills/house-rules/scripts -->
