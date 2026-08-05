# Area: tests — bash test suite for the house-rules deterministic scripts

> See @AGENTS.md at the repo root for repo-wide rules.

## Purpose

Verifies `skills/house-rules/scripts/` at the shell/exit-code level, not doc
content — `SKILL.md`'s instructions have no automated check. `run.sh` runs
via `.github/workflows/ci.yml` (twice, once per OS matrix leg) and the
README's "Tests" section; nothing else invokes these files.

## What's here

One executable `<name>.test.sh` per skill mode (`all.test.sh`,
`init.test.sh`, …), plus two non-test files: `lib.sh`, sourced by every test
via `. "$(dirname "$0")/lib.sh"`, and `run.sh`, which globs `*.test.sh`, runs
each with bash, and exits non-zero if any fails. `lib.sh` supplies
script-path variables (`$STALENESS`, `$BACKFILL`, …), assert helpers
(`check`, `check_contains`, `check_not_contains`), fixture builders
(`make_repo`, `commit_all`), and `finish`, which reports the tally and exit
code. Each test builds a throwaway git repo and traps its removal on EXIT.

## Tripwires

- Never use `mapfile` or associative arrays — `lib.sh` pins a bash 3.2
  compatibility floor, matching the scripts.
- Never create fixtures in the real working tree — every sibling builds an
  isolated `make_repo` tempdir and traps its deletion.

*Only relevant if you're adding a new resource of the same shape — skip the
next two sections otherwise.*

## Reference

`@./all.test.sh` — uses all three assert helpers and the standard
fixture-repo skeleton in the smallest file showing the full pattern.

## Extending

1. Create `tests/<mode>.test.sh` and `chmod +x` it; `@./run.sh` picks it up
   by glob — no registration.
2. Copy the skeleton from `@./all.test.sh`: header comment, `set -u`, source
   `lib.sh`, `repo="$(make_repo)"`, `trap 'rm -rf "$repo"' EXIT`, `cd "$repo"`.
3. Build fixtures with `mkdir`/`printf`, commit via `commit_all "$repo" <msg>`.
4. Assert with `check <desc> <expected-exit> $?`, or `check_contains` /
   `check_not_contains` on captured output.
5. End with `finish`; if testing a new script, add its path var to
   `@./lib.sh`.

<!-- Maintained by /house-rules. Pattern changed? Run: /house-rules tests -->
