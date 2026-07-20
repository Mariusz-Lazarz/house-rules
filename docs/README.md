# house-rules — docs

Start here: [how-it-works.md](how-it-works.md) — the parts, the lifecycle,
what the deterministic checks look at, and how to wire them into a gate of
your own (this project ships checks, not an installed hook).

Then one page per invocation mode:

| Invocation | Doc | In one line |
|---|---|---|
| `/house-rules` · `/house-rules <dir>` · `/house-rules <file.md>` | [directory-mode.md](directory-mode.md) | Document (or refresh) one directory's local file pattern |
| `/house-rules --all` | [all.md](all.md) | Find every undocumented candidate directory and document each via sub-agents |
| `/house-rules --init` | [init.md](init.md) | Onboard a repo: create the manifest and scaffold the root index, with consent |
| `/house-rules --check` | [check.md](check.md) | Audit doc freshness on demand — report only, changes nothing |
| `/house-rules --backfill` | [backfill.md](backfill.md) | Record manifest baselines for area docs that predate the manifest |

Shared machinery (the staleness engine, the lock manifest, the bundled
scripts) is described where it is used; wiring the checks into your own
pre-push hook or CI is covered in [how-it-works.md](how-it-works.md). Using
the skill outside Claude Code (Codex CLI and other Agent Skills–compatible
agents) is covered in the README's *Codex & other agents* section — every
command works the same there.
