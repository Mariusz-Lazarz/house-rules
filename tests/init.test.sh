#!/usr/bin/env bash
# Tests for the deterministic layer behind `/house-rules --init`:
# per-repo arming (manifest = opt-in switch for `/house-rules --check` and
# for any gate a user wires in themselves), baseline backfill, and
# fail-closed behavior on a corrupted manifest.
set -u
. "$(dirname "$0")/lib.sh"

repo="$(make_repo)"
trap 'rm -rf "$repo"' EXIT
cd "$repo"

mkdir libs
printf 'a\n' > libs/a.js
printf 'b\n' > libs/b.js
printf 'c\n' > libs/c.js
commit_all "$repo" init

mkdir -p .claude
printf '{ "version": 1, "dirs": {}, "ignore": [] }\n' > .claude/house-rules.lock.json

# --- Backfill: docs that predate the manifest get baselines; existing entries untouched.

echo docs > libs/AGENTS.md
commit_all "$repo" docs
"$STALENESS" write libs >/dev/null 2>&1

mkdir apps
printf 'p\n' > apps/p1.py
printf 'p\n' > apps/p2.py
echo docs > apps/AGENTS.md
commit_all "$repo" apps

out="$("$BACKFILL" --dry-run)"
check "backfill --dry-run exits 0" 0 $?
check_contains     "dry-run lists the missing-baseline dir" "would backfill: apps" "$out"
check_not_contains "dry-run skips already-baselined dirs"   "would backfill: libs" "$out"

before="$(grep -o '"libs": "[a-f0-9]*"' .claude/house-rules.lock.json)"
"$BACKFILL" >/dev/null 2>&1
check "backfill run exits 0" 0 $?
grep -q '"apps"' .claude/house-rules.lock.json
check "backfill recorded the missing baseline" 0 $?
after="$(grep -o '"libs": "[a-f0-9]*"' .claude/house-rules.lock.json)"
[ "$before" = "$after" ]
check "backfill never overwrites an existing baseline" 0 $?

out="$("$BACKFILL")"
check_contains "second backfill has nothing to do" "0 backfilled" "$out"

# A dir documented by a local CLAUDE.md is an area doc too — not a dead zone.
mkdir legacy
printf 'l\n' > legacy/l1.rb
printf 'l\n' > legacy/l2.rb
echo docs > legacy/CLAUDE.md
commit_all "$repo" legacy

out="$("$BACKFILL" --dry-run)"
check_contains "dry-run lists a CLAUDE.md-documented dir" "would backfill: legacy" "$out"
"$BACKFILL" >/dev/null 2>&1
grep -q '"legacy"' .claude/house-rules.lock.json
check "backfill baselines the CLAUDE.md dir" 0 $?
echo change >> legacy/l1.rb
"$STALENESS" check >/dev/null 2>&1
check "drift on a CLAUDE.md dir is now detectable (exit 1)" 1 $?
"$STALENESS" write legacy >/dev/null 2>&1

# A dir carrying both AGENTS.md and CLAUDE.md must be backfilled exactly once,
# not twice (the `processed` list in staleness-backfill.sh exists for this).
mkdir dualdoc
printf 'd\n' > dualdoc/d1.go
printf 'd\n' > dualdoc/d2.go
echo docs > dualdoc/AGENTS.md
echo docs > dualdoc/CLAUDE.md
commit_all "$repo" dualdoc

out="$("$BACKFILL" --dry-run)"
occurrences="$(printf '%s\n' "$out" | grep -c 'would backfill: dualdoc$')"
[ "$occurrences" = "1" ]
check "a dir with both AGENTS.md and CLAUDE.md is listed exactly once" 0 $?
"$BACKFILL" >/dev/null 2>&1
grep -q '"dualdoc"' .claude/house-rules.lock.json
check "the dual-doc dir got baselined" 0 $?
out="$("$BACKFILL")"
check_contains "a second backfill has nothing left for the dual-doc dir" "0 backfilled" "$out"

# --- Backfill denylist: same excluded trees as discover, kept in sync -------

mkdir -p vendor/pkg node_modules/dep .venv/lib
printf 'v\n' > vendor/pkg/AGENTS.md
printf 'n\n' > node_modules/dep/AGENTS.md
printf 'h\n' > .venv/lib/AGENTS.md
commit_all "$repo" denylist-dirs

out="$("$BACKFILL" --dry-run)"
check_not_contains "denylist: vendor/ is never backfilled"       "vendor/pkg" "$out"
check_not_contains "denylist: node_modules/ is never backfilled" "node_modules/dep" "$out"
check_not_contains "denylist: dotted dirs are never backfilled"  ".venv/lib" "$out"

# --- Fail-closed on a corrupted manifest ------------------------------------
# A botched merge of the lock file must block, not silently disarm the gate.
# Backup lives inside $repo (not bare /tmp) so the existing make_repo trap
# cleans it up like everything else in this test.

cp .claude/house-rules.lock.json ./hr-manifest.bak
printf '<<<<<<< ours\n{ "dirs": {} }\n=======\n{ }\n>>>>>>> theirs\n' > .claude/house-rules.lock.json

out="$("$STALENESS" check 2>&1)"; rc=$?
check "corrupted manifest fails the check (exit 1)" 1 "$rc"
check_contains "corruption message says what to do" "cannot be parsed" "$out"

"$STALENESS" discover >/dev/null 2>&1
check "discover refuses a corrupted manifest (exit 1)" 1 $?

out="$("$BACKFILL" --dry-run 2>&1)"; rc=$?
check "backfill --dry-run fails closed on a corrupted manifest (exit 1)" 1 "$rc"
check_contains "backfill --dry-run doesn't lie about what it would do" "cannot be parsed" "$out"
check_not_contains "backfill --dry-run does not claim to backfill an already-baselined dir" "would backfill: libs" "$out"

out="$("$BACKFILL" 2>&1)"; rc=$?
check "backfill (real run) fails closed on a corrupted manifest (exit 1)" 1 "$rc"
check_contains "backfill's real-run failure is the same clean message, not a Python traceback" "cannot be parsed" "$out"
check_not_contains "no raw Python traceback leaks to the user" "Traceback" "$out"

mv ./hr-manifest.bak .claude/house-rules.lock.json
"$STALENESS" check >/dev/null 2>&1
check "restored manifest passes again" 0 $?

finish
