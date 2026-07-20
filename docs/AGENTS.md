# Area: docs — one page per house-rules invocation mode, plus an overview and index

> See @AGENTS.md at the repo root for repo-wide rules.

## Shape

The unit is one Markdown page per invocation mode, named after the flag in kebab-case (`all.md` documents `/house-rules --all`; the flagless core mode gets `directory-mode.md`). A mode page opens with an H1 of the form `` # `/house-rules --all` — <one-phrase purpose> ``, then a short framing paragraph, then `##` sections — pipeline steps, tables, guarantees, edge cases, whatever the mode demands. Docs cross-link with relative Markdown links like `[init.md](init.md)`. `README.md` is the index: a start-here pointer to `how-it-works.md` plus a three-column table (Invocation | Doc | In one line) with one row per mode page.

## Reference

`@./directory-mode.md` — the core-mode page (documents the flagless invocation, the mode every other flag builds on) whose H1 convention, tables, and section style the other mode pages follow.

## Adding one more

1. Name the file after the flag or mode in kebab-case: `<mode>.md` (e.g. `all.md` for `--all`).
2. Open with an H1 like `` # `/house-rules --<flag>` — <one-phrase description> `` and a short framing paragraph, then copy the section layout from `@./directory-mode.md`.
3. Cross-link related pages with relative links like `[init.md](init.md)`, not absolute paths.
4. Register the page in `@./README.md`: add one row to the invocation table (Invocation | Doc | In one line).

## Tripwires

- Do not give shared machinery (the staleness engine, lock manifest, bundled scripts) its own page — `README.md` states it is described where it is used.

<!-- Maintained by /house-rules. Pattern changed? Run: /house-rules docs -->
