#!/usr/bin/env bash
# Tests for the deterministic layer behind `/house-rules --check`:
# the audit must run without a manifest, surface all three finding kinds
# (drift, undocumented candidates, missing baselines), and stay read-only.
set -u
. "$(dirname "$0")/lib.sh"

repo="$(make_repo)"
trap 'rm -rf "$repo"' EXIT
cd "$repo"

mkdir libs apps
printf 'a\n' > libs/a.js
printf 'b\n' > libs/b.js
printf 'p\n' > apps/p1.py
printf 'p\n' > apps/p2.py
commit_all "$repo" init

# --- unarmed repo: the audit still runs and creates nothing ---
out="$("$STALENESS" check 2>&1)"
check "check without a manifest exits 0 (audit continues)" 0 $?
check_contains "check says there is nothing to check" "no manifest" "$out"

out="$("$STALENESS" discover)"
check "discover works without a manifest" 0 $?
check_contains "discover still lists candidates" "libs" "$out"

[ ! -e .claude/house-rules.lock.json ]
check "read-only: neither check nor discover created a manifest" 0 $?

# --- discover output is the tab-separated triple the report parses ---
line="$(printf '%s\n' "$out" | grep '^libs')"
[ "$line" = "$(printf 'libs\t2\t.js')" ]
check "discover output format is '<dir>\\t<count>\\t<ext>'" 0 $?

# --- armed repo with one finding of each audit kind at once ---
echo docs > libs/AGENTS.md            # documented + baselined, then drifted
commit_all "$repo" docs
"$STALENESS" write libs >/dev/null 2>&1
echo change >> libs/a.js

echo docs > apps/AGENTS.md            # documented but never baselined
commit_all "$repo" apps-docs

mkdir tools                           # undocumented candidate
printf 't\n' > tools/t1.py
printf 't\n' > tools/t2.py
commit_all "$repo" tools

out="$("$STALENESS" check 2>&1)"; rc=$?
check "drift pass: exit 1 is a finding, not an execution error" 1 "$rc"
check_contains "drift pass names the dir and the refresh command" "/house-rules libs" "$out"
check_not_contains "drift pass stays silent about an unrelated, undrifted dir" "apps" "$out"

out="$("$STALENESS" discover)"
check_contains     "discovery pass flags the undocumented dir" "tools" "$out"
check_not_contains "discovery pass skips documented dirs" "apps" "$out"

out="$("$BACKFILL" --dry-run)"
check "missing-baseline pass exits 0" 0 $?
check_contains     "it lists the doc without a baseline" "would backfill: apps" "$out"
check_not_contains "it skips the already-baselined dir" "would backfill: libs" "$out"

# An UNTRACKED area doc must not be baselined: git can't see its directory, so
# the recorded hash would be empty and later turn into a phantom drift.
mkdir ghost
echo docs > ghost/AGENTS.md
echo x > ghost/x.js
out="$("$BACKFILL" --dry-run)"
check_not_contains "untracked area doc is not backfilled" "ghost" "$out"
git add ghost
out="$("$BACKFILL" --dry-run)"
check_contains "once tracked, the same doc is backfilled" "would backfill: ghost" "$out"
git reset -q -- ghost && rm -rf ghost

# --- the full audit is read-only: reruns change nothing, fix nothing ---
before="$(cat .claude/house-rules.lock.json)"
"$STALENESS" check >/dev/null 2>&1 || true
"$STALENESS" discover >/dev/null
"$BACKFILL" --dry-run >/dev/null
after="$(cat .claude/house-rules.lock.json)"
[ "$before" = "$after" ]
check "audit passes never modify the manifest" 0 $?

"$STALENESS" check >/dev/null 2>&1
check "findings persist after the audit (nothing auto-fixed)" 1 $?

# --- corrupt manifest: the audit must fail closed, not pass silently ---
cp .claude/house-rules.lock.json lock.bak
echo '{broken' > .claude/house-rules.lock.json
out="$("$STALENESS" check 2>&1)"; rc=$?
check "corrupt manifest: check fails closed (exit 1)" 1 "$rc"
check_contains "check says the manifest is unparseable" "cannot be parsed" "$out"
"$STALENESS" discover >/dev/null 2>&1
check "corrupt manifest: discover refuses too" 1 $?
mv lock.bak .claude/house-rules.lock.json

finish
