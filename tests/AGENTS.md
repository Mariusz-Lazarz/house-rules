# Area: tests — bash test suite for the house-rules deterministic scripts

> See @AGENTS.md at the repo root for repo-wide rules.

## Shape

One executable `<name>.test.sh` per skill mode (e.g. `all.test.sh` exercises the layer behind `/house-rules --all`, `init.test.sh` the manifest, backfill, and fail-closed corrupted-manifest behavior), plus two non-test files: `lib.sh`, sourced by every test via `. "$(dirname "$0")/lib.sh"`, and `run.sh`, which globs `*.test.sh`, runs each with bash, and exits non-zero if any fails. `lib.sh` supplies script-path variables (`$STALENESS`, `$BACKFILL`, …) resolved against `../skills/house-rules/scripts`, assert helpers (`check`, `check_contains`, `check_not_contains`), fixture builders (`make_repo`, `commit_all`), and `finish`, which prints the pass/fail tally and sets the file's exit code. Each test builds a throwaway git repo, cds into it, and traps its removal on EXIT.

## Reference

`@./all.test.sh` — uses all three assert helpers, env-var overrides, and the standard fixture-repo skeleton in the smallest file that still shows the full pattern.

## Adding one more

1. Create `tests/<mode>.test.sh` and `chmod +x` it; `@./run.sh` picks it up by glob — no registration.
2. Copy the skeleton from `@./all.test.sh`: header comment naming the mode under test, `set -u`, source `lib.sh`, `repo="$(make_repo)"`, `trap 'rm -rf "$repo"' EXIT`, `cd "$repo"`.
3. Build fixtures with `mkdir`/`printf` and commit via `commit_all "$repo" <msg>`.
4. Assert with `check <desc> <expected-exit> $?` for exit codes, or capture `out="$(...)"` and use `check_contains`/`check_not_contains`.
5. End the file with `finish`.
6. If testing a script `lib.sh` doesn't yet reference, add its path variable in `@./lib.sh` beside `$STALENESS`.

## Tripwires

- Never use `mapfile` or associative arrays — `lib.sh` pins a bash 3.2 compatibility floor, matching the scripts themselves.
- Never create fixtures in the real working tree — every sibling builds an isolated `make_repo` tempdir and traps its deletion.

<!-- Maintained by /house-rules. Pattern changed? Run: /house-rules tests -->
