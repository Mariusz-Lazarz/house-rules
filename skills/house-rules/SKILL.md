---
name: house-rules
description: >
  Write down a directory's house rules — its local file pattern — into a short
  AGENTS.md (120–250 words). Reads actual sibling files — naming, structure,
  imports, test co-location — then writes "here is the shape, here is the
  reference, here is how to add one more." Never asks about the project; infers
  everything from files on disk. Cites one real sibling as the canonical example.
  `--all` bulk-documents every candidate directory via sub-agents; `--init`
  onboards a project (creates the manifest `--check` reads, scaffolds the root
  index); `--check` audits doc freshness on demand (report only, changes nothing);
  `--backfill` records baselines for area docs that predate the manifest.
  Use when you want agents to follow the existing convention in a focused folder:
  API handlers, UI components, database migrations, hooks, workers, etc.
  Trigger phrases: "house rules", "what are the house rules here", "write the
  house rules for this folder", "document this directory's pattern", "add agents
  doc here", "what is the pattern here", "are the house rules up to date",
  "audit the agents docs", "backfill the baselines", "these docs predate the
  manifest".
---

# /house-rules — Write Down Each Folder's House Rules

Write a short `AGENTS.md` that tells the next agent exactly what shape things take
inside *this* directory and how to add one more, by reading the files already
there. No project-wide framing, no build commands, no commit conventions — those
belong in the root `AGENTS.md`. Just the local rules, derived from evidence.

## Bundled scripts

This skill ships with helper scripts inside its own folder, so it works the same
wherever the folder lives — the Claude Code plugin, a repo's `.agents/skills/`,
or `~/.agents/skills/`. Resolve their location once per run:

- **`$SKILL_ROOT`** = the directory containing this `SKILL.md`.
- The staleness engine is `$SKILL_ROOT/scripts/staleness.sh`
  (subcommands: `write`, `check`, `hash`, `discover`, `ignore`).
- The baseline backfiller is `$SKILL_ROOT/scripts/staleness-backfill.sh`.

All project state lives in the **target repo**, never in the plugin:
`.claude/house-rules.lock.json` (shape-hash baselines + discovery ignore list).
Never edit that manifest by hand — only through the scripts.

## First action — always

Before anything else, resolve the mode and target. This is a hard branch, not a
suggestion.

```
1. $ARGUMENTS is `--init`     → go to Init path.
2. $ARGUMENTS is `--all`      → go to All path.
3. $ARGUMENTS is `--check`    → go to Check path.
4. $ARGUMENTS is `--backfill` → go to Backfill path.
5. Otherwise resolve the target directory **and** the target file (see Input
   resolution below — the target file is `<target-dir>/AGENTS.md` unless a
   custom `.md` path was given), then:
   a. Is the target directory the repo root (`git rev-parse --show-toplevel`, when inside
      a git repo, resolves to the same directory)? → STOP: "/house-rules
      documents sub-directories only — it never writes the root rules file. For
      project onboarding (manifest + index skeleton) run /house-rules --init."
      Check this BEFORE the doc-length check below — a root `AGENTS.md` almost
      always exists and is almost always longer than 5 lines, which would
      otherwise silently route straight into Update path and start editing it.
   b. Is the target file a **custom name** (anything other than `AGENTS.md`/
      `CLAUDE.md`, e.g. `NOTES.md`) **and** does `<target-dir>/AGENTS.md` or
      `<target-dir>/CLAUDE.md` already exist with more than 5 lines? → STOP:
      "`<target-dir>` is already documented in `<existing-doc>` — house-rules
      keeps one area doc per directory. Run `/house-rules <target-dir>` to
      refresh it instead, or confirm you actually want a second file
      (`<target-file>`) for this directory." Only continue past this point if
      the user explicitly confirms the second file — never decide this
      yourself. (A directory with no existing area doc yet skips this check
      entirely; a custom name is exactly what Input resolution's `.md` case
      is for.)
   c. Does the target file exist and contain more than 5 lines?
      YES → go directly to Update path, on that exact file. Do NOT run
      Create path steps.
      NO  → go to Create path, writing that exact file.
```

Never silently overwrite a non-stub local doc. If one exists, update it — **in
its own file**: a directory documented by a local `CLAUDE.md` gets that
`CLAUDE.md` refreshed, never a parallel `AGENTS.md` created beside it. (If both
exist, `AGENTS.md` is the one this skill maintains.)

## Input resolution

`$ARGUMENTS` = the text the user passed after the skill name when invoking it
(Claude Code substitutes it literally; in other harnesses read it from the
invocation). It is optional.

- **Empty** → target directory is `pwd`.
- **A directory path** → use that directory as the target; the target file is
  `<target-dir>/AGENTS.md` (or `<target-dir>/CLAUDE.md` if that's the file the
  directory already carries — see the "never a parallel AGENTS.md" rule
  above).
- **A file path ending in `.md`** → that literal path is the target file;
  inspect its containing directory for siblings. If it's a custom name and the
  directory already has a real `AGENTS.md`/`CLAUDE.md`, First Action step 5b
  stops and asks before writing a second doc for the same directory.
- **`--all`** → no single target; enumerate every candidate directory missing an
  `AGENTS.md` and document each via a sub-agent. Go to **All path**.
- **`--init`** → no target; onboard the current repo. Go to **Init path**.
- **`--check`** → no target; audit the current repo's doc freshness. Go to
  **Check path**.
- **`--backfill`** → no target; record manifest baselines for pre-existing area
  docs. Go to **Backfill path**.

## What this skill does NOT do

- Does not ask the user "what is this project?" or "what framework do you use?" —
  it reads the files and infers. If inference is impossible (empty directory,
  no pattern to read), it says so and stops.
- Does not write project-level sections: no top-level directory map, no build
  scripts, no CI overview, no commit conventions. One line linking to the root
  `AGENTS.md` covers all of that.
- Does not invent conventions. Every sentence in the output must trace back to a
  real file on disk.
- Does not embed multi-line code blocks. Uses `@`-references to actual files.
- Does not write generic advice ("write clean code", "be consistent"). If a rule
  cannot be checked against a diff, it gets cut.

---

## Init path

Entered on `--init`. Onboards the current repo: creates the manifest that
`/house-rules --check` (and any freshness check the user wires into their own
pipeline) reads, and scaffolds the root index — **with the user's consent, and
without generating a single area doc**. Init builds the skeleton; documenting
directories is a separate, later decision. Init installs nothing and registers
no hooks — it only writes files inside the target repo.

1. **Verify the repo.** `git rev-parse --show-toplevel`. Not a git repo → stop:
   "`--init` needs a git repository." Everything below happens at that root.

2. **Take stock.** Check what already exists: `.claude/house-rules.lock.json`?
   A root `AGENTS.md` or `CLAUDE.md`? A `## Subdirectory Knowledge` section in
   either? And would git even track the manifest —
   `git check-ignore -q .claude/house-rules.lock.json` (works before the file
   exists; catches both a global excludesfile and the repo's `.gitignore`)?
   Report the current state in one or two lines before asking anything.

3. **Ask the user — one consent per action.** Ask only about actions whose target
   doesn't already exist; never redo what's already in place:
   - **Create the manifest?** `.claude/house-rules.lock.json` (skeleton:
     `{"version": 1, "dirs": {}, "ignore": []}`) is what `/house-rules --check`
     reads — shape-hash baselines and the discovery ignore list. Without this
     file `--check` has nothing to compare against.
   - **Un-ignore the manifest?** Offer this only when the take-stock
     `check-ignore` hit: the manifest is gitignored (people commonly ignore all
     of `.claude/`), so it would never be committed — teammates and CI would
     get no shared baselines; everything would work on this machine only.
     With consent, append to the **repo's** `.gitignore`:
     ```
     !.claude/
     .claude/*
     !.claude/house-rules.lock.json
     ```
     All three lines matter: negating just the file does nothing while the
     directory itself is ignored (git never descends into it), and `.claude/*`
     re-hides everything else there (e.g. `settings.local.json`). Declining is
     fine — a solo user may want the manifest local-only.
   - **Scaffold the index?** Add an **empty** `## Subdirectory Knowledge` section
     (the caption line only, zero bullets) to the root rules file. Use
     `AGENTS.md` if it exists, else `CLAUDE.md`. If **neither** exists, ask
     whether to create a minimal `AGENTS.md` containing only that section.

4. **Execute only what was approved.** Write the manifest via
   `Bash` (`mkdir -p .claude` + write the JSON skeleton — this one file is the
   exception to the never-by-hand rule, since the scripts create it on first
   `write`/`ignore` anyway). If un-ignoring was approved, append the three
   `.gitignore` lines shown above via `Edit`/`Bash`. Add the index section with
   a single `Edit`/`Write` touching nothing else in the file.

5. **Report.** What was created, what was skipped (already present / declined),
   and the natural next steps: `/house-rules <dir>` for one directory,
   `/house-rules --all` for every candidate at once, `/house-rules --check` to
   audit on demand, `/house-rules --backfill` if old area docs exist without
   baselines, and — if the user wants this enforced automatically — that
   `staleness.sh check`/`discover` (see `docs/how-it-works.md`) can be wired
   into a pre-push hook or CI step they write themselves; the skill doesn't
   install one.

The index section skeleton:

```markdown
## Subdirectory Knowledge

Scoped `AGENTS.md` docs, maintained by `/house-rules`.
```

---

## Check path

Entered on `--check`. Audits the current repo's doc freshness and reports —
nothing else. This path is **strictly read-only**: no `staleness.sh write`, no
`staleness.sh ignore`, no file edits, no consent questions, and no documenting.
Every finding comes with the command that would fix it; running any of them is
the user's next move, not yours.

1. **Verify the repo.** `git rev-parse --show-toplevel`. Not a git repo → stop:
   "`--check` needs a git repository."

2. **Is there a manifest?** If `.claude/house-rules.lock.json` is missing, note
   in the report that this repo hasn't run `/house-rules --init` yet — then
   continue anyway: discovery works without a manifest and shows what a check
   *would* flag.

3. **Drift.** Run `"$SKILL_ROOT/scripts/staleness.sh" check`. Exit 1 with `⚠`
   lines means drift was found — that is a finding, not an execution error.

4. **Discovery.** Run `"$SKILL_ROOT/scripts/staleness.sh" discover`. Each output
   line is `<dir>\t<count>\t<ext>` — a directory that qualifies for a doc but
   has none.

5. **Missing baselines.** Run
   `"$SKILL_ROOT/scripts/staleness-backfill.sh" --dry-run`. Area docs without a
   manifest entry are invisible to `check`, so the audit must surface them.

6. **Report.** Three sections, only for non-empty findings:
   - **Drift** — each stale dir with `→ refresh: /house-rules <dir>`;
   - **Undocumented candidates** — each dir with its file count/extension and
     the options: document (`/house-rules <dir>`) or ignore permanently (ask
     `/house-rules` to ignore it). Present the options; never pick one yourself.
   - **Missing baselines** — the dirs the backfiller would fill, pointing at
     `/house-rules --backfill`.

   All three empty → a single line: everything is documented, current, and
   baselined. If step 2 found no manifest, lead the report with that note.

---

## Backfill path

Entered on `--backfill`. Records manifest baselines for area docs
(`AGENTS.md`/`CLAUDE.md`) that predate the manifest or were never hashed —
fills only *missing* entries, never touches an existing baseline, so real
drift is never masked. No area doc is read or rewritten; this only records
shape hashes. This is the only supported way to run the backfiller — never
tell the user to invoke `staleness-backfill.sh` themselves.

1. **Verify the repo.** `git rev-parse --show-toplevel`. Not a git repo → stop:
   "`--backfill` needs a git repository."

2. **Preview.** Run `"$SKILL_ROOT/scripts/staleness-backfill.sh" --dry-run`.
   Empty / "0 to backfill" → report "nothing to backfill — every area doc
   already has a baseline" and stop. No consent question needed for a no-op.

3. **Ask the user once.** Show the list of dirs the dry-run would fill; ask a
   single yes/no to proceed. Never decide for them, and never skip straight to
   step 4 without asking.

4. **Execute.** On yes, run `"$SKILL_ROOT/scripts/staleness-backfill.sh"`
   (no `--dry-run`) via `Bash`.

5. **Report.** Which dirs were backfilled (from the script's own output), and
   that `/house-rules --check` will now see accurate baselines for them.

---

## Create path

### Step 1 — Survey the directory

Read the following (skip anything that doesn't apply):

1. **List siblings.** `ls -1` in the target directory. Note file count, dominant
   extension(s), naming convention (kebab-case, PascalCase, snake_case,
   `*.handler.ts`, `*_test.go`, etc.), any index/barrel file.
2. **Read 2–4 representative files.** Pick the most typical ones — not the largest,
   not one-offs. Read each enough to extract:
   - top-level imports (what does each file pull in, and from where?)
   - export style (default vs. named, class vs. function, barrel or not)
   - internal structure (sections, ordering, naming conventions inside the file)
   - co-located tests/styles/types? (are there sibling `*.test.*`, `*.spec.*`,
     `*.styles.*`, `*.types.*` files next to each unit?)
3. **Check for a barrel or index.** Does `index.*`, `mod.rs`, `__init__.py`, or
   similar exist? What does it re-export?
4. **Spot the test pattern.** Co-located (`*.test.ts`) or parallel tree
   (`__tests__/`, `spec/`)? What naming convention do test files use?
5. **Look for a nearby rule file.** Is there a `CLAUDE.md` or `AGENTS.md` one level
   up that mentions this directory? If so, read it and pull in only rules that
   directly apply here.

### Step 2 — Identify the reference sibling

Pick **one** file to hold up as the canonical example — the file another developer
would read first when adding a second unit. Criteria in priority order:

1. Closest to median size and complexity in the directory (not the smallest stub,
   not a special case, not the largest).
2. Has a visible test sibling or is the most complete representation of the pattern.
3. Named in the most obviously conventional way when naming is consistent.

If no clear winner, pick the most recently modified non-test file.

### Step 3 — Draft

Write the file per **Output structure** below. Target 120–250 words of body (headings
and the maintenance footer excluded from the count). Under 120 means the pattern wasn't captured; over 250
means scope crept into territory that belongs in the root `AGENTS.md`.

### Step 4 — Quality check (run before writing)

Each is a hard gate. Revise if any fails.

1. **No invented facts.** Every sentence traces to a file read in Step 1.
2. **No repo-level scope.** No build commands, no CI, no top-level directory map,
   no commit conventions. One `@AGENTS.md` link is the entire allowance.
3. **Reference sibling is cited.** `## Reference` names a real file via
   `@./filename` that was actually read.
4. **"Adding one more" is actionable.** The numbered list gives steps a new agent
   can follow without opening any other file.
5. **Body is 120–250 words.** Count the body (headings and the maintenance footer
   don't count). Trim if over; add specifics if under.
6. **No multi-line code blocks.** Single-line inline examples are fine. Anything
   longer → `@`-reference instead.
7. **No generic advice.** If you could have written a sentence without opening the
   directory, cut it.

### Step 5 — Write

Single `Write` call to the resolved path.

### Step 6 — Update the subdirectory knowledge index

Run the **Subdirectory knowledge index (always)** section below. The area-doc word-count
budget (120–250) is unaffected — the index lives in a different file.

### Step 7 — Record the directory's shape hash

Run the **Shape hash (always)** section below so `/house-rules --check` (or a
gate the user wires in themselves) knows this AGENTS.md is current as of the
directory's present contents.

Report back:
- path written
- body word count
- reference sibling chosen and why in one sentence
- subdirectory index: created / entry added / entry updated / skipped (no root file)
- shape hash: recorded value for the directory

---

## Update path

Entered when the resolved target file — `AGENTS.md`, a local `CLAUDE.md`, or a
confirmed custom name (see First Action step 5b) — already exists with more
than 5 lines. All edits go into **that same file** (a `CLAUDE.md`-documented
directory keeps its `CLAUDE.md`). The goal is a surgical edit, not a rewrite.
Preserve the user's authorial voice in anything that is still accurate.

1. **Read the existing file in full.** Note its sections, every `@./filename`
   reference it cites, and any explicit convention it states.

2. **Re-survey the directory** (same as Create path Step 1). Look specifically for:
   - New siblings added since the file was written (new files that match the
     pattern, or new files that break it).
   - Renamed or deleted files that the AGENTS.md still references.
   - Conventions that have drifted (e.g., the barrel export moved, the test naming
     changed, a new import origin appeared in all recent files).

3. **Classify every substantive line** into one of four buckets:
   - **KEEP** — still accurate; referenced file exists, convention holds.
   - **UPDATE** — directionally right but a detail is stale (renamed file,
     moved path, changed convention). Note the exact replacement.
   - **REMOVE** — the underlying file/convention no longer exists or has been
     contradicted by what you observed in Step 2.
   - **MISSING** — a real convention visible in current siblings that the file
     doesn't mention yet.

4. **Edit surgically.** Use `Edit` for each UPDATE / REMOVE / MISSING entry
   individually. Only use `Write` to replace the whole file if more than half the
   lines are classified as REMOVE or UPDATE. If the maintenance footer (see
   **Output structure**) is missing — docs written before it existed — append it
   as the last line.

5. **Re-run the quality check** (same seven gates as the Create path) on the
   result. If the body has grown past 250 words from MISSING additions, trim
   lower-leverage KEEP content rather than dropping the new information.

6. **Update the subdirectory knowledge index.** Run the **Subdirectory knowledge
   index (always)** section below.

7. **Record the directory's shape hash.** Run the **Shape hash (always)** section below.

8. **Report:** path, new body word count, one line each on what was updated, removed, and
   added (e.g. *"1 updated (reference sibling renamed), 0 removed, 1 added (barrel export
   wiring step)"*), the subdirectory index result (created / entry added / entry updated
   / skipped), and the recorded shape hash.

---

## All path

Entered when `$ARGUMENTS` is `--all`. Bulk-documents every candidate directory that is
**missing** an `AGENTS.md`. Existing area docs are never touched — refreshing them is
what per-directory `/house-rules <dir>` is for.

### Step 1 — Enumerate candidates

Run `"$SKILL_ROOT/scripts/staleness.sh" discover` from inside the target
repo. It encodes the bar: git-tracked dirs with >= 2 files of a dominant extension,
no `AGENTS.md`/`CLAUDE.md` of their own, and no manifest/ignore entry. Never scan
with `find` over the working tree — untracked trees must stay invisible.

### Step 2 — Safety filter (denylist)

The script already excludes dotted path segments and common vendor/system trees
(`node_modules`, `vendor`, `venv`, `dist`, `build`, `target`, `coverage`, …).
Re-check its output anyway and drop anything that is clearly generated or vendored
in this particular repo. A denylisted directory is never documented, even if it
clears the Step 1 bar.

### Step 3 — Confirm with the user

Show the filtered candidate list and ask the user to decide **per directory**:
**document** / **skip this run** / **ignore permanently**
(`"$SKILL_ROOT/scripts/staleness.sh" ignore <dir>`). Never decide on your
own. Empty list → report "nothing to do" and stop.

### Step 4 — Sub-agents, in batches of ~4

For each approved directory, spawn a sub-agent (Agent tool, general-purpose). Launch
at most ~4 at a time; start the next batch only when the previous one has finished.
(If the harness has no sub-agent tool — e.g. some non-Claude agents — process the
directories sequentially yourself, still following the Create path per directory
and still leaving the shared files to Step 5.)
Each sub-agent's prompt must instruct it to:

- follow this skill's **Create path** for `<dir>` (Survey → reference sibling → draft
  → the seven quality gates → single `Write`);
- write **only** `<dir>/AGENTS.md` — it must NOT touch the root `AGENTS.md` index or
  `.claude/house-rules.lock.json`; the parent performs both "always" steps afterward;
- report back: path written, body word count, reference sibling chosen, and the
  summary phrase from its `# Area: … — <summary>` heading.

### Step 5 — Serialize the shared files (parent)

After all sub-agents complete:

For each **documented** directory, in turn:
1. Upsert its bullet into the root `## Subdirectory Knowledge` list, following the
   **Subdirectory knowledge index (always)** section (upsert key `@<dir>/AGENTS.md`,
   bullets sorted by path, idempotent).
2. Run `"$SKILL_ROOT/scripts/staleness.sh" write <dir>`.

For each directory the user chose **ignore permanently** in Step 3, in turn:
3. Run `"$SKILL_ROOT/scripts/staleness.sh" ignore <dir>`. This is the step that
   actually fulfills the choice offered in Step 3 — without it, an "ignored"
   directory is never recorded anywhere and reappears as a candidate on the
   next `--all` or `--check`.

The manifest and the root index are the reason sub-agents must not write them:
concurrent edits to a shared file corrupt each other. Only the parent touches
them, serially.

### Step 6 — Aggregate report

One table: directory → outcome (documented / skipped / ignored) → body word count →
reference sibling → hash recorded yes/no.

---

## Shape hash (always)

Run this as the final step of **both** the Create path and the Update path, after
the area `AGENTS.md` is written. (In `--all` mode the parent runs it after the
sub-agents finish — a sub-agent skips it.) It records a hash of the directory's
current contents into the repo's `.claude/house-rules.lock.json`, so
`/house-rules --check` (or a gate the user wires in themselves) knows this
`AGENTS.md` is current as of the directory's present contents — for free,
without re-reading files.

Single command, run from inside the target repo:

```
"$SKILL_ROOT/scripts/staleness.sh" write <target-dir-relative-to-repo-root>
```

(e.g. `... write controllers`). The script owns the hashing algorithm — never
compute or edit the hash in the manifest by hand.

**Backfilling existing docs.** Area `AGENTS.md` files that predate the manifest
(no entry yet in `.claude/house-rules.lock.json`) need a baseline before
`--check` can see drift on them — that's what `/house-rules --backfill` is
for (see **Backfill path** above). Don't run `staleness-backfill.sh` directly
for the user; point them at the flag.

---

## Subdirectory knowledge index (always)

Run this as the final step of **both** the Create path and the Update path — every time
`/house-rules` documents a directory. (In `--all` mode the parent runs it after the
sub-agents finish — a sub-agent skips it.) It maintains a single index list in
the repo root that maps each scoped `AGENTS.md` to a few-word summary, so an agent
landing at the root can see what local docs exist and where.

This edits a **different file** from the area `AGENTS.md` you just wrote, so it does **not**
count against that file's 120–250 word budget.

1. **Resolve the repo root.** `git rev-parse --show-toplevel`. If not a git repo, walk up
   from the target directory to the first directory containing `AGENTS.md` or `CLAUDE.md`.
2. **Pick the root file.** Use `<root>/AGENTS.md` if it exists; otherwise fall back to
   `<root>/CLAUDE.md`. If **neither** exists, **skip this step** — report "no root rules file
   — index skipped". Never create a new root file here (that's `--init`'s job, with consent).
3. **Compute the entry** from the area doc you just wrote:
   - **Doc** = `@<path-relative-to-root>` with the doc's actual filename (e.g.
     `@routes/AGENTS.md`, or `@routes/CLAUDE.md` when that is the file the
     directory carries). This is the stable upsert key.
   - **Summary** = the phrase after ` — ` in that doc's `# Area:` heading. If the heading
     can't be parsed (no ` — `), fall back to the directory name and note it in the report.
4. **Upsert into the `## Subdirectory Knowledge` list** in the root file. Each entry is one
   bullet: `- @<doc> — <summary>`.
   - **No `## Subdirectory Knowledge` section yet** → append one: the caption line, then this
     bullet.
   - **Section exists, a bullet with the same Doc path exists** → `Edit` only that bullet's
     summary text.
   - **Section exists, no bullet for this doc** → insert a new bullet, keeping bullets sorted
     by Doc path.
   - Idempotent: running twice must never duplicate a bullet — match on the `@<path>` Doc.

Touch **only** the `## Subdirectory Knowledge` section. Never reflow or rewrite any other
content in the root file.

List format:

```markdown
## Subdirectory Knowledge

Scoped `AGENTS.md` docs, maintained by `/house-rules`.

- @controllers/AGENTS.md — Express CRUD handlers for REST resources
- @routes/AGENTS.md — Express routers mapping REST verbs to controller functions
```

---

## Output structure

```markdown
# Area: <directory-name> — <one-phrase description of what lives here>

> See @AGENTS.md at the repo root for repo-wide rules.

## Shape

<One paragraph. Name the dominant unit (component, handler, migration, hook, …),
its naming convention with one inline example, its internal structure, what it
imports, and what it exports. Note whether tests/styles/types are co-located or
live elsewhere.>

## Reference

`@./<reference-sibling>` — <one sentence on why this is the clearest example and
what makes it representative.>

## Adding one more

1. <Create a file named `<NamingConvention>.<ext>`.>
2. <Copy the shape from the reference: imports, skeleton, export style.>
3. <Wire it in — barrel re-export, route registration, migration runner, or
   whatever registration the siblings use. Cite the file: `@./<barrel-or-registry>`.>
4. <Add a co-located test at `<test-naming-pattern>` if tests live here.>
5. <Any step specific to this directory — generator, type discriminant, manifest
   update. Omit if no such step exists.>

## Tripwires

- <"Never do X" rule observed in siblings — only include if actually visible.>
- <Omit this section entirely if no tripwires are found.>

<!-- Maintained by /house-rules. Pattern changed? Run: /house-rules <dir-relative-to-repo-root> -->
```

**Notes:**

- `# Area:` signals immediately that this is a local, not repo-level, file.
- The `> See @AGENTS.md` line is the full allowance for repo-wide context — one
  line, not a paragraph.
- `## Shape` is discovery — what already exists.
- `## Reference` pins one file — the agent reads one, not five.
- `## Adding one more` is the reason this file exists.
- `## Tripwires` is optional and evidence-based — omit if nothing was observed.
- The closing HTML comment is the **maintenance footer**: invisible in rendered
  markdown, visible to any agent reading the raw file. It names the exact refresh
  command so nobody "fixes" the doc by hand when the pattern changes. It is
  metadata, not body — excluded from the 120–250 word count — and always the last
  line of the file.
- Do not add sections beyond these four. If something important doesn't fit here,
  it belongs in the root `AGENTS.md`.

---

## Edge cases

- **Empty or near-empty directory (0–1 source files).** Stop with: "Only `<N>`
  file(s) found — not enough siblings to infer a pattern. Add more files first, or
  describe the intended convention directly in `AGENTS.md`." Do not fabricate.
- **No dominant pattern (mixed types, irregular naming).** Write only what IS
  consistent across siblings and note explicitly that naming/structure varies. Do
  not invent a pattern.
- **All files are generated (migration timestamps, proto outputs, codegen).** Note
  the generator, cite its config or command, and replace "Adding one more" steps
  with "Use `<generator command>` — do not create these files by hand."
- **Existing `AGENTS.md` is empty or a stub (≤ 5 lines).** The "First action"
  gate sends this to Create path — overwrite is safe, there is no authorial
  content to preserve.
- **Target is the repo root.** Already caught by First Action step 5a, before
  either path is entered — listed here for completeness, not as a separate check.
- **Not a git repository.** The staleness scripts need git. Document the
  directory anyway, skip the shape-hash step, and note "shape hash: skipped
  (not a git repo)".
