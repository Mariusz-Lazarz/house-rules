# house-rules

[![CI](https://github.com/Mariusz-Lazarz/house-rules/actions/workflows/ci.yml/badge.svg)](https://github.com/Mariusz-Lazarz/house-rules/actions/workflows/ci.yml)

> Every folder has house rules. Write them down. Keep them true.

A Claude Code plugin (and portable [Agent Skill](https://developers.openai.com/codex/skills)
— works in Codex CLI too) that documents each directory's **local file pattern**
into a short `AGENTS.md` — and then keeps those docs honest with an on-demand
freshness check (`/house-rules --check`) you can wire into your own pre-push
hook or CI, if you want it automatic.

Every area doc answers three questions, inferred from the files actually on disk
(never from asking you):

> here is the shape → here is the reference file → here is how to add one more

## Install

```bash
claude plugin marketplace add Mariusz-Lazarz/house-rules
```

then inside Claude Code:

```
/plugin install house-rules
```

### Codex & other agents

The skill folder is self-contained and follows the open Agent Skills standard
(`SKILL.md` + bundled `scripts/`), so any compatible agent can run it:

```bash
npx skills add Mariusz-Lazarz/house-rules        # installs to .agents/skills/ and
                                                # symlinks into detected agents
```

or copy `skills/house-rules/` manually into `~/.agents/skills/` (user-wide) or
`<repo>/.agents/skills/` (per repo). Codex discovers both locations natively.
Every command below (`--init`, `--check`, `--all`, `--backfill`, `<dir>`)
works the same in Codex as in Claude Code.

## Quick start

```
/house-rules --init        # onboard a repo: create the manifest, scaffold the root index (asks first)
/house-rules src/handlers  # document one directory
/house-rules --all         # find every undocumented candidate dir, document each via sub-agents
/house-rules --check       # audit: drift + undocumented dirs + missing baselines, report only
/house-rules --backfill    # baseline area docs that predate the manifest
```

## What it does

### `/house-rules <dir>` — document one directory

Reads 2–4 representative sibling files, extracts the convention (naming, imports,
exports, test co-location), picks **one** real file as the canonical reference, and
writes a 120–250-word `<dir>/AGENTS.md`:

```markdown
# Area: handlers — HTTP endpoint handlers for the public API
> See @AGENTS.md at the repo root for repo-wide rules.
## Shape        ← what already exists
## Reference    ← the one file to copy from
## Adding one more  ← numbered, actionable steps
## Tripwires    ← observed "never do X" rules (only if real)
```

Runs on an existing doc → **surgical update**, not a rewrite (your wording is
preserved wherever it is still accurate).

After every doc it also:
1. upserts a one-line entry into a `## Subdirectory Knowledge` index in your root
   `AGENTS.md`/`CLAUDE.md`, so agents landing at the root see what local docs exist;
2. records the directory's **shape hash** into `.claude/house-rules.lock.json`.

### `/house-rules --all` — bulk mode

Enumerates every git-tracked directory that *looks* worth documenting (≥ 2 files of
a dominant extension, no `AGENTS.md`, not ignored), filters out vendor/system trees
(`node_modules`, `venv`, `dist`, dotted dirs, …), **asks you per directory**, then
documents the approved ones in parallel sub-agent batches. Shared files (root
index, lock manifest) are updated serially by the parent to avoid write races.

### `/house-rules --init` — onboard a project

Consent-driven scaffolding, generates **zero** docs:
- creates `.claude/house-rules.lock.json` — the shape-hash baselines and
  discovery ignore list that `/house-rules --check` reads;
- adds an empty `## Subdirectory Knowledge` section to your root rules file.

Each step is proposed first; nothing happens without a yes. Nothing gets
installed anywhere — `--init` only writes files inside your repo.

### `/house-rules --check` — audit on demand

The deterministic engine's report mode: which documented directories drifted,
which directories qualify for a doc but have none, and which area docs still
lack a baseline. Writes nothing, blocks nothing, asks for nothing — each
finding comes with the command that fixes it.

### `/house-rules --backfill` — baseline pre-existing docs

Records manifest baselines for area docs that predate
`.claude/house-rules.lock.json` (fills only missing entries, never
overwrites — real drift is never masked). Previews the list, asks once, then
writes. This is the only supported way to run the bundled backfiller — see
[`docs/backfill.md`](docs/backfill.md).

### Keeping docs honest — and wiring your own gate

`--check` is manual by design: this project ships the checks, not an
installed hook. If you want it automatic, the same deterministic engine
(`skills/house-rules/scripts/staleness.sh check` / `discover` — no LLM, git
blob SHAs hashed from the current worktree in milliseconds) is a couple of
lines to wire into your own `pre-push` hook or a CI step:

```sh
STALENESS=skills/house-rules/scripts/staleness.sh   # path from repo root, or wherever you installed the skill
[ -f .claude/house-rules.lock.json ] || exit 0        # this repo never ran --init
"$STALENESS" check                                    || exit 1
[ -z "$("$STALENESS" discover)" ]                     || { "$STALENESS" discover; exit 1; }
```

See [`docs/how-it-works.md`](docs/how-it-works.md) for the full recipe
(including a CI-step version).

## Project state

Everything lives in the target repo, nothing in the plugin:

| Path | Contents |
|---|---|
| `<dir>/AGENTS.md` | the area docs |
| root `AGENTS.md` / `CLAUDE.md` | the `## Subdirectory Knowledge` index |
| `.claude/house-rules.lock.json` | shape-hash baselines + discovery ignore list |

Adopting house-rules in a repo with pre-existing area docs? Run
`/house-rules --backfill` to baseline them (fills only missing entries, never
overwrites) — see [`docs/backfill.md`](docs/backfill.md).

## Tuning

| Env var | Default | Effect |
|---|---|---|
| `HOUSE_RULES_DISCOVER_MIN` | `2` | min files of the dominant extension before a dir is flagged |
| `HOUSE_RULES_DISCOVER_EXCLUDE` | – | extra comma-separated dir names discovery should skip |

## Documentation

In [`docs/`](docs/README.md):

- [`docs/how-it-works.md`](docs/how-it-works.md) — **start here**: all the parts, and how to wire the checks into your own gate
- [`docs/directory-mode.md`](docs/directory-mode.md) — `/house-rules [<dir> | <file.md>]`: document or refresh one directory
- [`docs/all.md`](docs/all.md) — `/house-rules --all`: bulk-document every undocumented candidate
- [`docs/init.md`](docs/init.md) — `/house-rules --init`: onboard a repo (manifest + index skeleton)
- [`docs/check.md`](docs/check.md) — `/house-rules --check`: audit doc freshness on demand, report only
- [`docs/backfill.md`](docs/backfill.md) — `/house-rules --backfill`: baseline area docs that predate the manifest

## Update / Uninstall

```bash
claude plugin update house-rules      # pull the latest version
claude plugin uninstall house-rules   # remove the plugin (skill)
```

Nothing else to clean up — house-rules never installs anything outside your
repo's `.claude/house-rules.lock.json` and the `<dir>/AGENTS.md` files it
writes. If you wired the checks into your own pre-push hook or CI, remove that
yourself the same way you added it. The generated `AGENTS.md` files are plain
docs in your repo either way; they stay (and stay useful) no matter what you
do with the plugin.

## Tests

```bash
tests/run.sh
```

Pure-bash, one file per invocation mode (`directory-mode`, `all`, `check`,
`init`); each builds a throwaway git repo and asserts on exit codes and output
of the bundled scripts. No LLM involved.

## Requirements

- git, bash (3.2+ — stock macOS works), python3 (3.8+)
- `sha256sum` **or** `shasum` (GNU coreutils / macOS — detected automatically)
- Claude Code with plugin support

## Notes

- `/house-rules` never writes your root rules file's prose — it only maintains the
  `## Subdirectory Knowledge` list, and only creates the file (minimal) if you
  approve it during `--init`.

## License

MIT
