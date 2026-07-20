# `/house-rules --backfill` — baseline pre-existing area docs

Records manifest baselines for area docs (`AGENTS.md`/`CLAUDE.md`) that
predate `.claude/house-rules.lock.json` or were otherwise never hashed. Fills
only *missing* entries — a dir already baselined is left untouched, so real
drift is never masked. No area doc is read or rewritten; this only records
shape hashes.

Typical use: adopting house-rules in a repo that already had `AGENTS.md`
files before anyone ran `/house-rules --init`, or after restoring an old
manifest that's missing entries for docs added since.

## Why this needs its own step

`/house-rules --check` only ever *reports* missing baselines — it never
writes one for you (`--check` is strictly read-only). Backfilling those gaps
is a separate, explicit action, and `--backfill` is the only supported way to
run it: the underlying script, `staleness-backfill.sh`, ships inside the
skill folder but isn't meant to be invoked by hand.

## What it does

1. **Preview.** Runs the bundled backfiller in dry-run mode, listing every
   area doc missing a baseline.
2. **Nothing to do?** An empty list ends the run there — "every area doc
   already has a baseline."
3. **Confirm.** Shows the list and asks once: proceed?
4. **Write.** On yes, runs the real backfill — one shape hash recorded per
   listed dir, none of the already-baselined ones touched.
5. **Report.** Which dirs got a baseline.

## After backfilling

`/house-rules --check` (or a gate you've wired into your own pre-push hook or
CI — see [how-it-works.md](how-it-works.md)) will now see accurate drift
status for those directories. If a dir was actually already stale when you
backfilled it, that drift is baked into the fresh baseline and won't surface
until the directory changes again — run `/house-rules <dir>` first if you
know a doc is already out of date, then `--backfill` the rest.
