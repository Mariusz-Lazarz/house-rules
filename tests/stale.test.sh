#!/usr/bin/env bash
# Tests for `staleness.sh stale`: same drift logic as `check`, but a clean
# one-dir-per-line list instead of `check`'s human-readable ⚠ report.
set -u
. "$(dirname "$0")/lib.sh"

repo="$(make_repo)"
trap 'rm -rf "$repo"' EXIT
cd "$repo"

mkdir libs apps
printf 'a\n' > libs/a.js
printf 'b\n' > libs/b.js
printf 'p\n' > apps/p1.py
commit_all "$repo" init

# --- no manifest: nothing to report, not an error ---
out="$("$STALENESS" stale)"
check "stale without a manifest exits 0" 0 $?
[ -z "$out" ]
check "stale without a manifest prints nothing" 0 $?

# --- clean manifest: baselined dirs, nothing changed since ---
echo docs > libs/AGENTS.md
echo docs > apps/AGENTS.md
commit_all "$repo" docs
"$STALENESS" write libs >/dev/null 2>&1
"$STALENESS" write apps >/dev/null 2>&1

out="$("$STALENESS" stale)"
check "stale on a clean manifest exits 0" 0 $?
[ -z "$out" ]
check "stale on a clean manifest prints nothing" 0 $?

# --- one drifted dir among two baselined dirs ---
echo change >> libs/a.js

out="$("$STALENESS" stale)"; rc=$?
check "stale exits 1 when something is stale" 1 "$rc"
check_contains     "stale lists the drifted dir" "libs" "$out"
check_not_contains "stale stays silent about the undrifted dir" "apps" "$out"
[ "$out" = "libs" ]
check "stale prints only the bare dir name, no decoration" 0 $?

# same fixture: cross-check against check's own findings
chk="$("$STALENESS" check 2>&1)"
check_contains "cross-check: check also flags libs" "libs" "$chk"

# --- manifest dir deleted from disk ---
rm -rf apps

out="$("$STALENESS" stale)"; rc=$?
check "stale exits 1 when a manifest dir is gone" 1 "$rc"
check_contains "stale lists the deleted dir" "apps" "$out"

# restore apps exactly as before (same content -> same hash), no git needed:
# the files are still tracked in the index, only the worktree copy was removed.
mkdir -p apps
printf 'p\n' > apps/p1.py
echo docs > apps/AGENTS.md

# --- corrupt manifest: fail closed, not silently clean ---
cp .claude/house-rules.lock.json lock.bak
echo '{broken' > .claude/house-rules.lock.json
out="$("$STALENESS" stale 2>/dev/null)"
[ -z "$out" ]
check "corrupt manifest: stdout is empty" 0 $?
err="$("$STALENESS" stale 2>&1 1>/dev/null)"; rc=$?
check "corrupt manifest: stale fails closed (exit 1)" 1 "$rc"
check_contains "corrupt manifest: stale reports it on stderr" "cannot be parsed" "$err"
mv lock.bak .claude/house-rules.lock.json

finish
