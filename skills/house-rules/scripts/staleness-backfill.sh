#!/usr/bin/env bash
#
# staleness-backfill.sh — record shape hashes for area-doc dirs (AGENTS.md or
# CLAUDE.md) that don't have one yet, without touching dirs already baselined.
#
# Why: `staleness.sh write <dir>` only records a hash when /house-rules runs
# on that dir. Repos that adopted house-rules late have older AGENTS.md
# files with no baseline in .claude/house-rules.lock.json. This backfills exactly
# those — the "only fill missing" semantics — so it never overwrites (and never
# masks drift on) a dir that already has a recorded hash.
#
# Usage:
#   staleness-backfill.sh [--dry-run]
#
# Exit status: 0 on success (including "nothing to do"); non-zero on error.

set -euo pipefail

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
elif [[ -n "${1:-}" ]]; then
  echo "usage: $(basename "$0") [--dry-run]" >&2
  exit 2
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

# The writer is this script's sibling inside the plugin, not a repo path.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WRITER="$SCRIPT_DIR/staleness.sh"
LOCK=".claude/house-rules.lock.json"

if [[ ! -x "$WRITER" ]]; then
  echo "error: $WRITER not found or not executable (broken plugin install?)" >&2
  exit 1
fi

# A present-but-unparseable manifest must fail closed, same as staleness.sh
# check/discover: silently treating it as "no baselines yet" would make every
# already-baselined dir look unbackfilled, and --dry-run would lie about what
# it's about to do.
if [[ -f "$LOCK" ]]; then
  if ! python3 -c \
    'import json,sys; d=json.load(open(sys.argv[1])); assert isinstance(d.get("dirs", {}), dict)' \
    "$LOCK" 2>/dev/null; then
    echo "⚠ $LOCK cannot be parsed (merge conflict? hand edit?) — fix or delete it, then re-run /house-rules" >&2
    exit 1
  fi
fi

# Already-baselined dirs (repo-root-relative keys under .dirs). Empty if no lock yet.
# (while-read instead of mapfile, python3 instead of jq: stock macOS ships bash 3.2
# and no jq, and python3 is already a hard dependency of the engine.)
baselined=()
if [[ -f "$LOCK" ]]; then
  while IFS= read -r k; do
    [[ -n "$k" ]] && baselined+=("$k")
  done < <(python3 -c 'import json,sys
for k in sorted(json.load(open(sys.argv[1])).get("dirs", {})):
    print(k)' "$LOCK")
fi

is_baselined() {
  local d="$1"
  for b in "${baselined[@]:-}"; do
    [[ "$b" == "$d" ]] && return 0
  done
  return 1
}

filled=0
skipped=0
processed=()

is_processed() {
  local d="$1"
  for p in "${processed[@]:-}"; do
    [[ "$p" == "$d" ]] && return 0
  done
  return 1
}

# All non-root area-doc dirs (AGENTS.md or CLAUDE.md), repo-root-relative.
# Only git-tracked docs count — an untracked/gitignored AGENTS.md must not
# baseline a directory git can't see (its shape hash would be empty and later
# turn into a phantom drift). Untracked trees are invisible by construction,
# same as discover; committed vendor trees are still skipped by name — same
# denylist as staleness.sh's discover, kept in sync on purpose. A dir
# carrying both docs shows up twice — the processed list keeps it to one backfill.
while IFS= read -r -d '' file; do
  dir="$(dirname "$file")"
  [[ "$dir" == "." ]] && continue   # skip the repo-root rules file
  case "/$dir/" in
    */node_modules/*|*/bower_components/*|*/vendor/*|*/venv/*|*/env/*|*/site-packages/*|*/__pycache__/*|*/dist/*|*/build/*|*/out/*|*/target/*|*/coverage/*|*/.*/*|*/*.egg-info/*) continue ;;
  esac

  if is_processed "$dir"; then
    continue
  fi
  processed+=("$dir")

  if is_baselined "$dir"; then
    skipped=$((skipped + 1))
    continue
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "would backfill: $dir"
  else
    echo "backfilling: $dir"
    "$WRITER" write "$dir"
  fi
  filled=$((filled + 1))
done < <(git -c core.quotepath=off ls-files -z -- '*/AGENTS.md' '*/CLAUDE.md')

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "dry run: $filled to backfill, $skipped already baselined"
else
  echo "done: $filled backfilled, $skipped already baselined"
fi
