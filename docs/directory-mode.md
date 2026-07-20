# `/house-rules [<dir> | <file.md>]` — document one directory

The core mode. Reads the files that already live in a directory and writes a short
`<dir>/AGENTS.md` (120–250 words of body) capturing the local convention: *here is
the shape → here is the reference file → here is how to add one more.*

It never asks what the project is or which framework you use — every sentence must
trace back to a real file on disk. If there is nothing to infer, it says so and
stops instead of inventing a pattern.

## Target resolution

| You type | Target |
|---|---|
| `/house-rules` | the current working directory |
| `/house-rules src/handlers` | that directory |
| `/house-rules src/handlers/NOTES.md` | output goes to that file; siblings are read from its containing directory — **unless** `src/handlers` already has a real `AGENTS.md`/`CLAUDE.md`, in which case it stops and asks first (house-rules keeps one area doc per directory) |
| `/house-rules .` at the repo root | **refused** — the root rules file is never written by this skill; use `--init` for onboarding |

## Create vs. Update — a hard branch

The first action is always the same check: does the target `AGENTS.md` exist with
more than 5 lines?

**No (or a ≤5-line stub) → Create path**

1. Survey: list siblings, read 2–4 representative files (imports, export style,
   internal structure, co-located tests/styles/types), check for a barrel/index,
   spot the test pattern.
2. Pick **one** reference sibling — the file closest to median size and complexity,
   not the smallest stub, not a special case.
3. Draft the doc, then pass seven quality gates (no invented facts, no repo-level
   scope, reference actually cited, actionable steps, 120–250 words, no multi-line
   code blocks, no generic advice). Any failure → revise before writing.
4. Single `Write`.

**Yes → Update path** (a local `CLAUDE.md` counts too, and is refreshed in
place — the skill never creates a parallel `AGENTS.md` beside it)

A surgical edit, not a rewrite. Every substantive line is classified
**KEEP / UPDATE / REMOVE / MISSING** against a fresh survey of the directory, and
only the stale/missing parts are touched. Your own wording is preserved wherever
it is still accurate. The whole file is rewritten only when more than half the
lines changed classification.

## What a run also does (both paths)

1. **Root index upsert** — one bullet per doc in the `## Subdirectory Knowledge`
   list of the root `AGENTS.md`/`CLAUDE.md` (`- @<dir>/AGENTS.md — <summary>`),
   keyed by path, sorted, idempotent. Only that section is ever touched.
2. **Shape hash** — records the directory's current shape into
   `.claude/house-rules.lock.json` via the bundled `staleness.sh write <dir>`,
   so `/house-rules --check` (or a gate you wire in yourself) can later detect
   drift for free. The hash is built from
   git blob SHAs of the directory's direct tracked files (excluding the doc
   itself — `AGENTS.md`/`CLAUDE.md`), hashed from the current worktree content
   in milliseconds; no LLM is involved. A custom target file (say `NOTES.md`)
   is not on that exclusion list — it counts as a regular file, so hand-editing
   it registers as drift until the next `/house-rules` run re-baselines.

## Output format

```markdown
# Area: <dir> — <one-phrase description>
> See @AGENTS.md at the repo root for repo-wide rules.
## Shape          ← the observed convention, one paragraph
## Reference      ← the single canonical sibling, @-cited
## Adding one more ← numbered steps a new agent can follow blind
## Tripwires      ← observed "never do X" rules; omitted when none were seen
<!-- Maintained by /house-rules. Pattern changed? Run: /house-rules <dir> -->
```

The closing HTML comment is a maintenance footer: invisible when rendered, but it
tells anyone reading the raw file how to refresh the doc instead of editing it by
hand. It doesn't count toward the word budget.

No other sections. Anything that doesn't fit belongs in the root rules file.

## Edge cases

- **0–1 source files** → stops: not enough siblings to infer a pattern.
- **Mixed types, irregular naming** → documents only what *is* consistent and says
  the rest varies; never invents.
- **Generated files** (migrations, codegen) → cites the generator and replaces
  "Adding one more" with "use the generator, don't create these by hand".
- **Not a git repo** → the doc is still written; the shape-hash step is skipped
  with a note.
