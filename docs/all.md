# `/house-rules --all` — bulk-document every candidate directory

One invocation that finds every directory *worth* documenting but *missing* an
`AGENTS.md`, asks you which ones to cover, then documents the approved ones with
parallel sub-agents. Existing area docs are never touched — refreshing one is what
per-directory `/house-rules <dir>` is for.

Typical use: adopting house-rules in an established repo, or catching up after a
feature branch added several new directories.

## The pipeline

### 1. Enumerate

Runs the bundled `staleness.sh discover`, which flags a directory when all
of these hold:

- it contains **≥ 2 git-tracked files** sharing a dominant extension
  (`HOUSE_RULES_DISCOVER_MIN` overrides the threshold);
- it has **no `AGENTS.md` / `CLAUDE.md`** of its own;
- it has **no entry** in the manifest — neither documented (`.dirs`) nor
  suppressed (`.ignore`).

Only `git ls-files` output is consulted — untracked and gitignored trees are
invisible by construction, and no file contents are read.

### 2. Filter

A denylist drops vendor/system directories even when they are committed:
`node_modules`, `bower_components`, `vendor`, `venv`, `env`, `site-packages`,
`__pycache__`, `dist`, `build`, `out`, `target`, `coverage`, every dotted path
segment, and `*.egg-info`. Extend it per shell with
`HOUSE_RULES_DISCOVER_EXCLUDE="dirA,dirB"`.

### 3. Confirm — the user decides, per directory

The filtered list is shown and each directory gets an explicit decision:

- **document** — proceed;
- **skip this run** — do nothing now, it will be flagged again;
- **ignore permanently** — recorded in the manifest's `ignore` list; never
  flagged again by `--all`, `/house-rules --check`, or `staleness.sh discover`.

An empty list ends the run with "nothing to do".

### 4. Document — sub-agents in batches

Approved directories are processed by sub-agents, at most ~4 in flight. Each
sub-agent runs the normal Create path for its directory and writes **only**
`<dir>/AGENTS.md`.

### 5. Serialize the shared files

Two files are shared by every run — the root `## Subdirectory Knowledge` index and
`.claude/house-rules.lock.json` — so sub-agents are forbidden from touching them.
After all batches finish, the parent updates both **serially**: one index bullet
and one `staleness.sh write <dir>` per documented directory. This is what
prevents concurrent-write corruption.

### 6. Report

A single table: directory → outcome (documented / skipped / ignored) → body word
count → reference sibling → hash recorded.

## Guarantees

- **Idempotent** — a second `--all` right after the first reports "nothing to do".
- **Threshold-respecting** — a directory with one file is never documented; the
  bar is the same one the per-directory skill applies (≥ 2 consistent siblings).
- **Consent-driven** — no directory is documented or permanently ignored without
  the user saying so.
