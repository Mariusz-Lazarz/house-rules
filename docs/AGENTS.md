# Area: docs — one page per house-rules invocation mode, plus an overview and index

> See @AGENTS.md at the repo root for repo-wide rules.

## Purpose

Explains the skill's modes to a human reader; the root `README.md`'s
"Documentation" section links here, treating `docs/README.md` as the index.
Nothing else in the repo reads these files — pure prose, never parsed by the
scripts or the skill itself.

## What's here

One page per invocation mode, named after the flag in kebab-case (`all.md`
documents `--all`; the flagless core mode gets `directory-mode.md`). A page
opens with an H1 (`` # `/house-rules --all` — <purpose> ``), a framing
paragraph, then `##` sections — pipeline steps, tables, guarantees, edge
cases. Pages cross-link with relative links like `[init.md](init.md)`.
`README.md` is the index: a pointer to `how-it-works.md` plus a table
(Invocation | Doc | In one line), one row per page.

## Reference

`@./directory-mode.md` — the core-mode page, whose H1 convention, tables, and
section style the other mode pages follow.

## Extending

1. Name the file after the flag: `<mode>.md`.
2. Open with an H1 like `` # `/house-rules --<flag>` — <description> `` and a
   framing paragraph, then copy the layout from `@./directory-mode.md`.
3. Cross-link related pages with relative links, not absolute paths.
4. Register the page in `@./README.md`'s invocation table.

## Tripwires

- Do not give shared machinery (the staleness engine, lock manifest, bundled
  scripts) its own page — `README.md` states it is described where it is
  used.

<!-- Maintained by /house-rules. Pattern changed? Run: /house-rules docs -->
