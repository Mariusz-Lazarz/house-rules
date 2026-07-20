# `/house-rules --check` — audit doc freshness on demand

A read-only audit of the whole repo: are the area `AGENTS.md` docs still true,
and is anything missing? It runs the same deterministic checks you could wire
into your own pre-push hook or CI (see *Wiring it into your own gate* in
[how-it-works.md](how-it-works.md)), but **reports instead of blocking** — it
writes nothing, ignores nothing, and asks for no consent. Every finding ends
with the command that fixes it; running that command is your next move, not
the audit's.

Useful any time nothing is watching automatically — this project doesn't
install a gate, so `--check` is the default way to see where things stand:
after a big merge or rebase from main (someone else's changes may have gone
stale), before pointing agents at a repo you haven't touched in a while, or as
the whole freshness story in a repo that never wires the checks into anything
else. It doesn't even require a manifest — without one it simply notes that
and shows what a check *would* flag once `--init` creates one.

## What it checks

Three passes, all built on the bundled scripts (no LLM — the same near-free
machinery a gate you build would use):

| Pass | Engine | Finds |
|---|---|---|
| **Drift** | `staleness.sh check` | Documented dirs whose shape hash no longer matches the baseline — the `AGENTS.md` may be stale |
| **Discovery** | `staleness.sh discover` | Dirs that qualify for a doc (≥ 2 files of a dominant extension) but have none and aren't ignored |
| **Missing baselines** | `staleness-backfill.sh --dry-run` | Area docs with no manifest entry — invisible to `check` until backfilled |

The third pass matters in repos that adopted house-rules late: an `AGENTS.md`
written before the manifest existed has no baseline, so drift on it can never
be detected until it's backfilled.

## The report

One section per non-empty pass, each finding paired with its remedy:

| Finding | Next move |
|---|---|
| a documented dir drifted | `/house-rules <dir>` — refresh the doc and the baseline |
| an undocumented candidate | `/house-rules <dir>` to document it, or ask `/house-rules` to ignore it permanently |
| a doc without a baseline | `/house-rules --backfill` |

All passes clean → a single line: everything is documented, current, and
baselined.

## `--check` vs. a gate you wire in yourself

Same checks, different posture:

- **a gate you build** (a pre-push hook, a CI step — see
  [how-it-works.md](how-it-works.md)) fires wherever you wired it and
  **blocks** until the findings are handled or however your own script lets
  you skip it;
- **`--check`** fires when you ask and only **reports** — nothing is blocked,
  nothing is written, and for discovery candidates it presents the options
  (document / ignore) without deciding anything for you.

Under the hood both call the same scripts, so a clean `--check` means any gate
built on the same checks would pass too.
