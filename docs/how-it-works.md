# How house-rules works

The whole system in one page: the parts, the lifecycle, what the deterministic
checks look at, and how to wire them into a gate of your own — this project
ships the checks, not an installed hook.

## The parts

| Part | Where it lives | What it is |
|---|---|---|
| Skill `/house-rules` | plugin, `skills/house-rules/` | LLM instructions for writing/refreshing area docs (`<dir>`, `--all`, `--init`, `--check`, `--backfill`); the folder is self-contained (scripts bundled inside), so it also runs as a portable Agent Skill in Codex & friends |
| Staleness engine | skill, `skills/house-rules/scripts/staleness.sh` | plain bash+python: `write` / `check` / `hash` / `discover` / `ignore`; never invokes an LLM |
| Backfiller | skill, `skills/house-rules/scripts/staleness-backfill.sh` | baselines pre-existing docs; fills only missing entries; run via `/house-rules --backfill`, never invoked by hand |
| Area docs | your repo, `<dir>/AGENTS.md` | the product: 120–250-word local-convention docs |
| Root index | your repo, root `AGENTS.md`/`CLAUDE.md` | `## Subdirectory Knowledge` — one bullet per area doc |
| Manifest | your repo, `.claude/house-rules.lock.json` | shape-hash baselines (`dirs`) + discovery suppressions (`ignore`); also the per-repo opt-in marker `--check` (or your own gate) looks for |

Everything stateful lives in **your repo**; the plugin itself is stateless and
installs nothing outside it.

## The core idea: shape hashes

When `/house-rules` writes a doc for `src/handlers/`, it records that directory's
**shape hash** — a 12-hex digest built from git blob SHAs of the directory's
direct tracked files (the doc itself excluded). Each SHA is computed over the
file's *current worktree content* (`git hash-object`) — that's precisely how
uncommitted edits are seen — and costs milliseconds even for large directories.
No LLM is involved.

Later, anyone can recompute the hash and compare it with the recorded baseline:

- **match** → the directory looks the same as when the doc was written → doc trusted;
- **mismatch (drift)** → files were added/removed/renamed/edited → the doc may lie.

The cheap hash gates the expensive step (re-running the LLM skill) — that's the
entire trick.

## Lifecycle

```
install plugin          →  skill available everywhere; nothing installed in any repo yet
/house-rules --init      →  (per repo, with consent) manifest created,
                           root index scaffolded
/house-rules <dir>|--all →  area docs written, index bullets upserted,
                           baselines recorded in the manifest
… normal work …         →  code changes freely; nothing watches automatically
/house-rules --check     →  (anytime) drift + discovery, reported — nothing
                           blocked, nothing written
(optional) your own gate →  wire `staleness.sh check`/`discover` into a
                           pre-push hook or CI step — see below
```

## The two deterministic checks

Everything the skill's freshness story is built on comes down to two checks,
callable directly (`staleness.sh check` / `discover`) or through
`/house-rules --check`'s formatted report ([docs/check.md](check.md) has the
full report format):

**1. Drift (`check`)** — for every directory in the manifest's `dirs`, recompute
the shape hash and compare with the baseline. Any mismatch (or a documented
directory that vanished) is a finding:

```
⚠ src/handlers/ changed since its AGENTS.md was generated (a1b2… → c3d4…)
    → re-run:  /house-rules src/handlers
```

Exits 1 if anything is stale (0 if clean, or if there's no manifest — nothing
to check yet).

**2. Discovery (`discover`)** — scan git-tracked directories for ones that *look*
worth documenting but have no doc: ≥ 2 direct files sharing a dominant extension,
no `AGENTS.md`/`CLAUDE.md`, not in `dirs`, not in `ignore`, not a vendor/dotted
directory. Prints one `<dir>\t<count>\t<ext>` line per hit and always exits 0 —
deciding whether that's worth blocking on is the caller's job, not the
engine's.

Neither check touches anything: no files written, nothing blocked, by
themselves. Whether a finding becomes a blocked push, a failed CI run, or just
a line in a report is entirely up to whatever calls them.

## Wiring it into your own gate

This project ships the checks, not an installed hook — `/house-rules --check`
covers the on-demand case. If you want it enforced automatically, wire the
same two checks into whatever runs at the point you want:

**A git `pre-push` hook** (`.git/hooks/pre-push`, or your own hook manager):

```sh
#!/bin/sh
STALENESS=/path/to/house-rules/skills/house-rules/scripts/staleness.sh
ROOT="$(git rev-parse --show-toplevel)" || exit 0
[ -f "$ROOT/.claude/house-rules.lock.json" ] || exit 0   # this repo never ran --init

fail=0
"$STALENESS" check || fail=1
cand="$("$STALENESS" discover)"
[ -z "$cand" ] || { printf '%s\n' "$cand"; fail=1; }
exit "$fail"
```

**A CI step** (any CI; shown as a generic shell step):

```sh
staleness=path/to/house-rules/skills/house-rules/scripts/staleness.sh
"$staleness" check
cand="$("$staleness" discover)"
[ -z "$cand" ] || { printf '%s\n' "$cand"; exit 1; }
```

Both use the exact same engine `/house-rules --check` uses — a clean
`--check` today means either recipe would pass too. Levers available to
either:

| Lever | Effect |
|---|---|
| manifest `ignore` entry (`staleness.sh ignore <dir>`) | a directory is permanently exempt from `discover` |
| no `.claude/house-rules.lock.json` | both checks are no-ops for that repo — nothing to compare against |

Want drift to warn instead of block in your own gate? That's just how you
write the recipe — swap `fail=1` (or `exit 1`) for a plain `echo`. The engine
has no separate "warn-only" mode to configure; your script's own exit code is
the only lever that matters.

## Limits, honestly

- **Nothing runs unless you wire it in.** `--init` only creates the manifest;
  no hook, no CI config, no cron. `/house-rules --check` is the only thing
  that runs the checks out of the box, and only when you ask.
- Drift detection is per-directory shape, not per-fact: it can't tell *which*
  sentence of a doc went stale, only that the directory changed. The refresh run
  (Update path) figures out the rest.
- Discovery's ≥2-files bar means a directory with one file is invisible until a
  second file appears — matching the skill's own refusal to infer a pattern from
  a single sibling.
- The checks look at the **worktree**, not any particular committed ref:
  uncommitted changes in a documented directory count as drift even when the
  commits themselves predate the change. Cheap by design (`git hash-object` on
  current content) — refresh the doc when that's what you meant.
