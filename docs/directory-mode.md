# `/house-rules [<dir> | <file.md>]` — document one directory

The core mode. Reads the files that already live in a directory and writes a short
`<dir>/AGENTS.md` (120–250 words of body) capturing what the directory is for, and
its local convention or per-file responsibilities: *here is the purpose → here is
what's here → here are its tripwires, if any → here is the reference and how to
extend it, when cloning a same-shape resource applies.*

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
   internal structure, co-located tests/styles/types, cross-layer field-name/
   casing consistency, the error-signaling convention in use, the
   validation-vs-persistence boundary, and any foreign-key/join/cross-resource
   references), check for a barrel/index, spot the test pattern, and grep the
   repo for external call-sites/imports of this directory to ground its
   `## Purpose`.
2. Pick **one** reference sibling **if one genuinely stands out** — the file
   closest to median size and complexity, not the smallest stub, not a special
   case — otherwise skip and omit `## Reference` (common when files serve
   distinct, non-repeatable responsibilities).
3. Draft the doc, then pass the quality gates (no invented facts, no
   repo-level scope, Purpose grounded in real call-sites, Tripwires bullets
   that require cross-file synthesis rather than restating one file,
   Reference/Extending included only when evidence-backed, actionable
   Extending steps when present, 120–250 words, no multi-line code blocks, no
   generic advice). Any failure → revise before writing.
4. Single `Write`.

**Yes → Update path** (a local `CLAUDE.md` counts too, and is refreshed in
place — the skill never creates a parallel `AGENTS.md` beside it)

A surgical edit, not a rewrite. Every substantive line is classified
**KEEP / UPDATE / REMOVE / MISSING** against a fresh survey of the directory, and
only the stale/missing parts are touched. Your own wording is preserved wherever
it is still accurate. The whole file is rewritten only when more than half the
lines changed classification.

## What a run also does (both paths)

Every run (Create or Update) records the directory's current shape as a
**shape hash** into `.claude/house-rules.lock.json` via the bundled
`staleness.sh write <dir>`, so `/house-rules --check` (or a gate you wire in
yourself) can later detect drift for free. The hash is built from git blob
SHAs of the directory's direct tracked files (excluding the doc itself —
`AGENTS.md`/`CLAUDE.md`), hashed from the current worktree content in
milliseconds; no LLM is involved. A custom target file (say `NOTES.md`) is not
on that exclusion list — it counts as a regular file, so hand-editing it
registers as drift until the next `/house-rules` run re-baselines.

It never touches the root `## Subdirectory Knowledge` note — that's a static
pointer written once by `--init`, not a per-directory list this mode updates.

## Output format

```markdown
# Area: <dir> — <one-phrase description>
> See @AGENTS.md at the repo root for repo-wide rules.
## Purpose        ← what decisions this dir owns vs. what's decided elsewhere
## What's here    ← evidence-based inventory + relations to other entities — always present
## Tripwires      ← non-obvious cross-file facts (casing, error convention, validation
                    boundary); OPTIONAL, read first among the optional sections since
                    it pays off on any task, not just cloning
[one-line note: relevant only when cloning a same-shape resource]
## Reference      ← the single canonical/entry-point sibling, @-cited — OPTIONAL
## Extending      ← numbered clone-steps, or a concrete extension point — OPTIONAL
<!-- Maintained by /house-rules. Pattern changed? Run: /house-rules <dir> -->
```

`## Purpose` and `## What's here` are always present. `## Tripwires`,
`## Reference`, and `## Extending` are each included only when the directory's
files actually support them — a single cohesive module (an SDK client, a
config file) may legitimately carry only Purpose and What's here. `## Reference`
and `## Extending` matter only when the task is cloning a same-shape resource;
`## Tripwires` matters regardless of task type.

The closing HTML comment is a maintenance footer: invisible when rendered, but it
tells anyone reading the raw file how to refresh the doc instead of editing it by
hand. It and the one-line cloning-scope note above `## Reference` don't count
toward the word budget.

No other sections. Anything that doesn't fit belongs in the root rules file.

## Edge cases

- **0–1 source files** → stops: not enough siblings to infer a pattern.
- **Mixed types, irregular naming** → documents only what *is* consistent and says
  the rest varies; never invents.
- **No repeatable unit — a single cohesive module** (an SDK client, a config
  module, one integration) → `## Reference` and `## Extending` are both
  legitimately optional and may both be omitted; `## Purpose` and `## What's
  here` carry the doc.
- **Generated files** (migrations, codegen) → cites the generator and replaces
  `## Extending` with "use the generator, don't create these by hand".
- **Not a git repo** → the doc is still written; the shape-hash step is skipped
  with a note.
