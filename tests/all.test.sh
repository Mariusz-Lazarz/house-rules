#!/usr/bin/env bash
# Tests for the deterministic layer behind `/house-rules --all`:
# candidate discovery (threshold, denylist, env overrides) and ignore.
set -u
. "$(dirname "$0")/lib.sh"

repo="$(make_repo)"
trap 'rm -rf "$repo"' EXIT
cd "$repo"

mkdir libs single vendor apps
printf 'a\n' > libs/a.js
printf 'b\n' > libs/b.js
printf 'c\n' > libs/c.js
printf 'x\n' > single/only.go
printf 'v\n' > vendor/v1.js
printf 'v\n' > vendor/v2.js
printf 'v\n' > vendor/v3.js
printf 'p\n' > apps/p1.py
printf 'p\n' > apps/p2.py
mkdir .hidden
printf 'h\n' > .hidden/h1.sh
printf 'h\n' > .hidden/h2.sh
commit_all "$repo" init

out="$("$STALENESS" discover)"
check "discover exits 0" 0 $?
check_contains     "flags a dir with >=2 files of a dominant ext" "libs" "$out"
check_contains     "flags a second qualifying dir"                "apps" "$out"
check_not_contains "threshold: 1-file dir is not flagged"         "single" "$out"
check_not_contains "denylist: committed vendor/ is not flagged"   "vendor" "$out"
check_not_contains "denylist: dotted dirs are not flagged"        ".hidden" "$out"

# The rest of the denylist beyond vendor/dotted — shared with staleness-backfill.sh
# but exercised here against `discover` itself, which has its own implementation.
mkdir -p bower_components env __pycache__ pkg.egg-info
printf 'a\n' > bower_components/a.js
printf 'b\n' > bower_components/b.js
printf 'a\n' > env/a.py
printf 'b\n' > env/b.py
printf 'a\n' > __pycache__/a.pyc
printf 'b\n' > __pycache__/b.pyc
printf 'a\n' > pkg.egg-info/a.txt
printf 'b\n' > pkg.egg-info/b.txt
commit_all "$repo" denylist-extra
out="$("$STALENESS" discover)"
check_not_contains "denylist: bower_components/ is not flagged" "bower_components" "$out"
check_not_contains "denylist: env/ is not flagged"               "env" "$out"
check_not_contains "denylist: __pycache__/ is not flagged"       "__pycache__" "$out"
check_not_contains "denylist: *.egg-info is not flagged"         "egg-info" "$out"

out="$(HOUSE_RULES_DISCOVER_MIN=4 "$STALENESS" discover)"
check_not_contains "HOUSE_RULES_DISCOVER_MIN raises the bar" "libs" "$out"

out="$(HOUSE_RULES_DISCOVER_EXCLUDE=libs "$STALENESS" discover)"
check_not_contains "HOUSE_RULES_DISCOVER_EXCLUDE drops a dir" "libs" "$out"
check_contains     "HOUSE_RULES_DISCOVER_EXCLUDE leaves others alone" "apps" "$out"

echo docs > apps/AGENTS.md
commit_all "$repo" docs
out="$("$STALENESS" discover)"
check_not_contains "a dir with its own AGENTS.md is not flagged" "apps" "$out"

"$STALENESS" ignore libs >/dev/null 2>&1
check "ignore records the suppression" 0 $?
out="$("$STALENESS" discover)"
check_not_contains "ignored dir is never flagged again" "libs" "$out"

"$STALENESS" write apps >/dev/null 2>&1
out="$("$STALENESS" discover)"
[ -z "$out" ]
check "documented + ignored + below-threshold = discover is empty (idempotence)" 0 $?

finish
