#!/usr/bin/env bash
# staleness.sh — detect when a directory has drifted from its house-rules AGENTS.md.
#
# A directory's "shape hash" is derived from git's per-file blob SHAs of its
# *direct* tracked files (the doc itself — AGENTS.md or CLAUDE.md — excluded). `/house-rules` records this hash in
# the manifest whenever it (re)writes an AGENTS.md. Whoever checks it later —
# `/house-rules --check`, or a hook/CI step you wire in yourself — recomputes
# the hash and compares: a mismatch means the directory changed since its
# AGENTS.md was generated, so the doc may be stale.
#
# Computing the hash is near-free: one `git hash-object` per direct file hashes
# the current worktree content exactly the way git does (that's how uncommitted
# edits are seen) — milliseconds even for large dirs. The hash exists only to gate
# the expensive part — re-running the /house-rules LLM skill — which a human/agent
# does after seeing a warning. This script never invokes an LLM.
#
# All state lives in the target repo at .claude/house-rules.lock.json. This script
# is location-independent: run it from anywhere inside a git repo.
#
# Usage:
#   staleness.sh check             # check every manifest dir; exit 1 if any stale
#   staleness.sh write    <dir>    # record <dir>'s current worktree hash
#   staleness.sh hash     <dir>    # print one dir's hash and exit
#   staleness.sh discover          # list tracked dirs that look worth scoping
#                                  #   but have no AGENTS.md (informational; exit 0,
#                                  #   except exit 1 on an unparseable manifest —
#                                  #   fail closed, same as `check`)
#   staleness.sh ignore   <dir>    # mark <dir> as never-a-candidate for discover
#
# Tuning (env vars):
#   HOUSE_RULES_DISCOVER_MIN        min files of the dominant extension to flag a dir (default 2)
#   HOUSE_RULES_DISCOVER_EXCLUDE    extra comma-separated dir names to exclude from discovery
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"
MANIFEST=".claude/house-rules.lock.json"

# Portable SHA-256: GNU coreutils has sha256sum; stock macOS only has shasum.
_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum; else shasum -a 256; fi
}

# dir_hash <dir> -> 12-hex shape hash of the dir's direct tracked files
# (blob SHA of current worktree content per file). quotepath=off so non-ASCII
# filenames come out raw, not octal-quoted — a quoted literal would make
# hash-object fail silently and blind the drift check for that file.
dir_hash() {
  local dir="${1%/}" rel
  git -c core.quotepath=off ls-files -- "$dir/" | while read -r path; do
    rel="${path:$((${#dir}+1))}"
    case "$rel" in */*|AGENTS.md|CLAUDE.md) continue ;; esac
    # `--` guards dash-leading names; a file deleted from the worktree hashes
    # to nothing (still ≠ baseline → drift) without leaking git's fatal noise
    # into the gate's block message.
    printf '%s %s\n' "$path" "$(git hash-object -- "$path" 2>/dev/null)"
  done | LC_ALL=C sort | _sha256 | cut -c1-12
}

# normalize_subdir <dir> — canonicalize before validating or recording: drop
# leading `./` segments and trailing slashes so `./docs/` and `docs` land on
# the same manifest key (and hash the same — dir_hash's doc exclusion compares
# repo-relative paths, so a `./` offset would break it).
normalize_subdir() {
  local d="$1"
  while [ "${d#./}" != "$d" ]; do d="${d#./}"; done
  while [ "${d%/}" != "$d" ]; do d="${d%/}"; done
  printf '%s' "$d"
}

# require_subdir <dir> <cmd> — reject arguments that would poison the manifest:
# the repo root, parent escapes, absolute paths, and `.`/`..`/empty path
# segments anywhere (callers normalize first, so a leading `./` never arrives).
require_subdir() {
  case "$1" in
    ""|.|..|/*|../*|*/..|*/../*|*/.|*/./*|*//*)
      echo "error: staleness.sh $2 needs a repo-relative subdirectory, got: $1" >&2
      exit 2 ;;
  esac
}

cmd_write() {
  local dir="${1:-}"; dir="$(normalize_subdir "$dir")"
  [ -n "$dir" ] || { echo "usage: staleness.sh write <dir>" >&2; exit 2; }
  require_subdir "$dir" write
  [ -L "$dir" ] && { echo "error: $dir is a symlink — house-rules can't track drift through symlinked directories" >&2; exit 2; }
  [ -d "$dir" ] || { echo "error: $dir is not a directory (relative to the repo root)" >&2; exit 2; }
  [ -f "$dir/AGENTS.md" ] || [ -f "$dir/CLAUDE.md" ] || \
    echo "note: $dir has no AGENTS.md/CLAUDE.md yet (recording hash anyway)" >&2
  mkdir -p "$(dirname "$MANIFEST")"
  local h; h="$(dir_hash "$dir")"
  MANIFEST="$MANIFEST" python3 - "$dir" "$h" <<'PY'
import json, os, sys
m = os.environ["MANIFEST"]
d, h = sys.argv[1], sys.argv[2]
data = {"version": 1, "dirs": {}}
if os.path.exists(m):
    with open(m) as f:
        data = json.load(f)
data.setdefault("dirs", {})[d] = h
with open(m, "w") as f:
    json.dump(data, f, indent=2, sort_keys=True)
    f.write("\n")
PY
  echo "recorded $dir -> $h in $MANIFEST"
}

cmd_check() {
  if [ ! -f "$MANIFEST" ]; then
    echo "no manifest ($MANIFEST) — nothing to check"
    return 0
  fi
  local stale=0 dir want got
  # A present-but-unparseable manifest must fail closed: the read loop below
  # would get zero lines from a crashed parser and silently pass, disarming the
  # gate exactly when the lock file was mangled (typically a botched merge).
  if ! MANIFEST="$MANIFEST" python3 -c \
    'import json,os; d=json.load(open(os.environ["MANIFEST"])); assert isinstance(d.get("dirs", {}), dict)' \
    2>/dev/null; then
    echo "⚠ $MANIFEST cannot be parsed (merge conflict? hand edit?) — fix or delete it, then re-run /house-rules"
    stale=1
  else
    # Tab-separated so a directory name containing spaces survives the read.
    while IFS=$'\t' read -r dir want; do
      if [ -L "$dir" ] || [ ! -d "$dir" ]; then
        echo "⚠ $dir/ is in the manifest but the directory is gone — drop it or re-run /house-rules"
        stale=1; continue
      fi
      got="$(dir_hash "$dir")"
      if [ "$got" != "$want" ]; then
        echo "⚠ $dir/ changed since its AGENTS.md was generated ($want → $got)"
        echo "    → re-run:  /house-rules $dir"
        stale=1
      fi
    done < <(MANIFEST="$MANIFEST" python3 -c 'import json,os;[print(f"{k}\t{v}") for k,v in json.load(open(os.environ["MANIFEST"])).get("dirs",{}).items()]')
  fi
  return "$stale"
}

cmd_hash() {
  local dir="${1:-}"; dir="$(normalize_subdir "$dir")"
  [ -n "$dir" ] || { echo "usage: staleness.sh hash <dir>" >&2; exit 2; }
  require_subdir "$dir" hash
  [ -L "$dir" ] && { echo "error: $dir is a symlink — house-rules can't track drift through symlinked directories" >&2; exit 2; }
  [ -d "$dir" ] || { echo "error: $dir is not a directory (relative to the repo root)" >&2; exit 2; }
  dir_hash "$dir"
}

# cmd_discover — find tracked dirs that look like house-rules candidates but have no
# AGENTS.md yet. Uses only `git ls-files` (no file contents read), so it's as cheap as
# `check`. A dir qualifies when it has >= HOUSE_RULES_DISCOVER_MIN direct files sharing a
# dominant extension, no AGENTS.md/CLAUDE.md of its own, and isn't already tracked
# (manifest .dirs) or suppressed (manifest .ignore). Prints "<dir>\t<count>\t<ext>" per
# candidate; exits 0 unless the manifest exists but can't be parsed (exit 1, fail
# closed — the same finding `check` already reports, not a second bug). Surfacing
# candidates themselves is always the caller's job, never a block. This mirrors the bar
# /house-rules itself uses (>=2 consistent siblings), so it never flags what the skill
# would refuse to document.
cmd_discover() {
  MANIFEST="$MANIFEST" MIN="${HOUSE_RULES_DISCOVER_MIN:-2}" \
  EXTRA_EXCLUDE="${HOUSE_RULES_DISCOVER_EXCLUDE:-}" python3 - <<'PY'
import json, os, subprocess, sys
from collections import defaultdict, Counter

MIN = int(os.environ.get("MIN", "2"))
manifest = os.environ["MANIFEST"]
data = {}
if os.path.exists(manifest):
    try:
        data = json.load(open(manifest))
    except ValueError:
        print(f"{manifest} cannot be parsed (merge conflict? hand edit?) — fix or delete it", file=sys.stderr)
        sys.exit(1)
skip = set(data.get("dirs", {})) | set(data.get("ignore", []))

# Never candidates: VCS/dep/build/generated trees and any dotted path segment.
# Git-tracking usually keeps these out already (they tend to be gitignored), but
# the denylist guards against committed vendor/, .venv, dist/ and the like.
EXCLUDE = {
    ".git", "node_modules", "bower_components", "vendor",
    "venv", "env", "site-packages", "__pycache__",
    "dist", "build", "out", "target", "coverage",
}
EXCLUDE |= {d.strip() for d in os.environ.get("EXTRA_EXCLUDE", "").split(",") if d.strip()}

def excluded(segment):
    return segment in EXCLUDE or segment.startswith(".") or segment.endswith(".egg-info")

direct = defaultdict(list)   # dir -> [filename, ...]  (direct children only)
documented = set()           # dirs that already carry an AGENTS.md/CLAUDE.md

tracked = subprocess.run(["git", "-c", "core.quotepath=off", "ls-files"],
                         capture_output=True, text=True,
                         check=True).stdout.splitlines()
for path in tracked:
    d, _, name = path.rpartition("/")
    if not d:
        continue  # repo-root files: the root is out of scope for /house-rules
    if any(excluded(p) for p in d.split("/")):
        continue
    if name in ("AGENTS.md", "CLAUDE.md"):
        documented.add(d)
    else:
        direct[d].append(name)

out = []
for d, names in direct.items():
    if d in skip or d in documented:
        continue
    exts = Counter(e for n in names if (e := os.path.splitext(n)[1]))
    if not exts:
        continue
    # A tie between two extensions with the same count breaks on Counter's
    # insertion order (first-seen wins), which itself follows `git ls-files`'
    # ordering. Deterministic for a given tree, but not a documented or
    # guaranteed contract — don't rely on which extension wins a tie.
    ext, cnt = exts.most_common(1)[0]
    if cnt >= MIN:
        out.append((d, cnt, ext))

for d, cnt, ext in sorted(out):
    print(f"{d}\t{cnt}\t{ext}")
PY
}

cmd_ignore() {
  local dir="${1:-}"; dir="$(normalize_subdir "$dir")"
  [ -n "$dir" ] || { echo "usage: staleness.sh ignore <dir>" >&2; exit 2; }
  # (No existence check: an ignored dir may legitimately vanish later.)
  require_subdir "$dir" ignore
  mkdir -p "$(dirname "$MANIFEST")"
  MANIFEST="$MANIFEST" python3 - "$dir" <<'PY'
import json, os, sys
m = os.environ["MANIFEST"]
d = sys.argv[1]
data = {"version": 1, "dirs": {}}
if os.path.exists(m):
    data = json.load(open(m))
ig = set(data.get("ignore", []))
ig.add(d)
data["ignore"] = sorted(ig)
with open(m, "w") as f:
    json.dump(data, f, indent=2, sort_keys=True)
    f.write("\n")
PY
  echo "ignoring $dir for discovery (recorded in $MANIFEST)"
}

case "${1:-}" in
  check)    shift; cmd_check    "$@" ;;
  write)    shift; cmd_write    "$@" ;;
  hash)     shift; cmd_hash     "$@" ;;
  discover) shift; cmd_discover "$@" ;;
  ignore)   shift; cmd_ignore   "$@" ;;
  *) echo "usage: staleness.sh {check|write <dir>|hash <dir>|discover|ignore <dir>}" >&2; exit 2 ;;
esac
