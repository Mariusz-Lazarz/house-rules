# `/house-rules --init` — onboard a repository

Consent-driven scaffolding for a repo that wants house-rules. It builds the
skeleton — the manifest `/house-rules --check` reads, and the root index — and
generates **zero** area docs. Documenting directories is a separate, later
decision (`/house-rules <dir>` or `--all`). `--init` installs nothing and
registers no hooks; it only writes files inside the repo.

## What it proposes

`--init` first reports the repo's current state, then asks **one consent per
missing piece** — it never redoes what already exists and never acts without a yes:

### 1. Create the manifest

Creates the manifest skeleton:

```json
// .claude/house-rules.lock.json
{ "version": 1, "dirs": {}, "ignore": [] }
```

This is what `/house-rules --check` reads: shape-hash baselines and the
discovery ignore list. Without it, `--check` has nothing to compare against.
Nothing is installed or wired into anything by this step — it's just a file.

**Is the manifest even trackable?** Lots of setups gitignore all of `.claude/`
(often via a global excludesfile). Then the manifest never reaches the repo:
baselines aren't shared, teammates and CI see nothing, and everything works on
one machine only — silently. `--init` detects this up front
(`git check-ignore -q .claude/house-rules.lock.json`) and, as a separate
consent, offers to append an exception to the repo's `.gitignore`:

```gitignore
!.claude/
.claude/*
!.claude/house-rules.lock.json
```

All three lines are needed — negating just the file does nothing while the
directory is ignored (git never descends into it), and `.claude/*` re-hides the
rest (e.g. `settings.local.json`). Declining is fine for solo use: `--check`
still works locally, the baselines just aren't shared.

### 2. Scaffold the root index

Adds an **empty** `## Subdirectory Knowledge` section (caption line, zero bullets)
to the root rules file — `AGENTS.md` if present, else `CLAUDE.md`. If neither
exists, it asks separately whether to create a minimal `AGENTS.md` containing only
that section. Future documenting runs upsert their bullets here.

That's the whole of `--init`. It doesn't install a hook or touch anything
outside the repo — `/house-rules --check` is what you run to actually see
drift and discovery findings, whenever you want. If you want that enforced
automatically instead of on demand, see *Wiring it into your own gate* in
[how-it-works.md](how-it-works.md) — a few lines of shell calling the same
`staleness.sh check`/`discover` this skill uses internally, dropped into
whatever pre-push hook or CI step you already have.

## After init — catching up an existing repo

If the repo already had area `AGENTS.md` files before adopting house-rules,
they have no baselines yet, so `check` ignores them. Run
`/house-rules --backfill` to fill exactly the missing ones (never overwriting
existing entries, so real drift is never masked) — see
[backfill.md](backfill.md).

Then silence any false-positive discovery candidates once (ask `/house-rules`
to ignore a directory), and the repo is fully adopted.
