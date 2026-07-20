#!/usr/bin/env bash
# Tests for the deterministic layer behind `/house-rules <dir>`:
# shape hashing, baseline write, drift detection.
set -u
. "$(dirname "$0")/lib.sh"

repo="$(make_repo)"
trap 'rm -rf "$repo"' EXIT
cd "$repo"

mkdir src
printf 'a\n' > src/a.js
printf 'b\n' > src/b.js
printf 'c\n' > src/c.js
commit_all "$repo" init

"$STALENESS" write src >/dev/null 2>&1
check "write records a baseline" 0 $?

"$STALENESS" check >/dev/null 2>&1
check "check passes on an unchanged dir" 0 $?

h1="$("$STALENESS" hash src)"
grep -q "$h1" .claude/house-rules.lock.json
check "manifest contains the recorded hash" 0 $?

echo change >> src/a.js
"$STALENESS" check >/dev/null 2>&1
check "editing a tracked file is drift (exit 1)" 1 $?

"$STALENESS" write src >/dev/null 2>&1
"$STALENESS" check >/dev/null 2>&1
check "re-recording the baseline clears drift" 0 $?

h2="$("$STALENESS" hash src)"
echo docs > src/AGENTS.md
commit_all "$repo" docs
h3="$("$STALENESS" hash src)"
[ "$h2" = "$h3" ]
check "AGENTS.md itself is excluded from the shape hash" 0 $?

echo docs > src/CLAUDE.md
commit_all "$repo" claudedocs
h3b="$("$STALENESS" hash src)"
[ "$h2" = "$h3b" ]
check "CLAUDE.md is excluded from the shape hash too" 0 $?

mkdir src/deep
echo x > src/deep/d.js
commit_all "$repo" deep
h4="$("$STALENESS" hash src)"
[ "$h2" = "$h4" ]
check "nested files don't affect the parent dir's hash (direct files only)" 0 $?

echo y > src/new.js
commit_all "$repo" newfile
"$STALENESS" check >/dev/null 2>&1
check "adding a direct file is drift" 1 $?

"$STALENESS" write src >/dev/null 2>&1
git -C "$repo" rm -q src/b.js
commit_all "$repo" rmfile
"$STALENESS" check >/dev/null 2>&1
check "removing a direct file is drift" 1 $?
"$STALENESS" write src >/dev/null 2>&1

# --- Filenames git would quote (core.quotepath): drift must still be seen ----

mkdir intl
printf 'a\n' > "intl/żółć.js"
printf 'b\n' > intl/ok.js
commit_all "$repo" intl
"$STALENESS" write intl >/dev/null 2>&1
"$STALENESS" check >/dev/null 2>&1
check "non-ASCII filename: clean dir passes" 0 $?
echo change >> "intl/żółć.js"
"$STALENESS" check >/dev/null 2>&1
check "non-ASCII filename: edit is drift (exit 1)" 1 $?
"$STALENESS" write intl >/dev/null 2>&1

# --- Directory name with a space: manifest round-trip must survive -----------

mkdir "my libs"
printf 'a\n' > "my libs/a file.js"
commit_all "$repo" spacedir
"$STALENESS" write "my libs" >/dev/null 2>&1
"$STALENESS" check >/dev/null 2>&1
check "dir name with a space: clean dir passes" 0 $?
echo change >> "my libs/a file.js"
"$STALENESS" check >/dev/null 2>&1
check "dir name with a space: edit is drift (exit 1)" 1 $?
"$STALENESS" write "my libs" >/dev/null 2>&1

# --- Argument validation: junk must not poison the manifest ------------------

"$STALENESS" write . >/dev/null 2>&1
check "write . (repo root) is rejected" 2 $?
"$STALENESS" write /tmp >/dev/null 2>&1
check "write with an absolute path is rejected" 2 $?
"$STALENESS" write ../elsewhere >/dev/null 2>&1
check "write escaping the repo is rejected" 2 $?
"$STALENESS" write nonexistent >/dev/null 2>&1
check "write on a missing directory is rejected" 2 $?
"$STALENESS" ignore .. >/dev/null 2>&1
check "ignore .. is rejected" 2 $?
"$STALENESS" write src/../src >/dev/null 2>&1
check "write with an interior .. segment is rejected" 2 $?
"$STALENESS" ignore a/../b >/dev/null 2>&1
check "ignore with an interior .. segment is rejected" 2 $?
"$STALENESS" write src/. >/dev/null 2>&1
check "write with a trailing . segment is rejected" 2 $?
"$STALENESS" write a//b >/dev/null 2>&1
check "write with an empty path segment is rejected" 2 $?
"$STALENESS" hash nonexistent >/dev/null 2>&1
check "hash on a missing directory is rejected (not a silent empty hash)" 2 $?
"$STALENESS" hash .. >/dev/null 2>&1
check "hash escaping the repo is rejected (not a raw git fatal + fake hash)" 2 $?
"$STALENESS" hash /tmp >/dev/null 2>&1
check "hash with an absolute path is rejected" 2 $?
"$STALENESS" hash . >/dev/null 2>&1
check "hash . (repo root) is rejected" 2 $?
"$STALENESS" ignore not-yet-created-dir >/dev/null 2>&1
check "ignore on a syntactically valid but not-yet-existing dir still succeeds" 0 $?
ig="$(python3 -c 'import json;print(",".join(json.load(open(".claude/house-rules.lock.json")).get("ignore",[])))')"
check_contains "the not-yet-existing dir is recorded in ignore anyway" "not-yet-created-dir" "$ig"
"$STALENESS" check >/dev/null 2>&1
check "rejected arguments left the manifest clean (check still passes)" 0 $?

# --- Path normalization: ./dir and dir/ are the same manifest key ------------
# Without this, `write ./src` would add a second key with a different hash and
# the doc-exclusion in dir_hash (a relative-path compare) would silently break.

"$STALENESS" write ./src >/dev/null 2>&1
check "write ./dir is accepted" 0 $?
keys="$(python3 -c 'import json;print(",".join(sorted(json.load(open(".claude/house-rules.lock.json"))["dirs"])))')"
check_not_contains "write ./dir normalizes to the existing key (no ./src)" "./src" "$keys"
check_contains "the normalized key is present" "src" "$keys"
h1="$("$STALENESS" hash src)"
h2="$("$STALENESS" hash ./src/)"
check "hash ./dir/ equals hash dir" 0 "$([ "$h1" = "$h2" ] && echo 0 || echo 1)"
echo doc-only-edit >> src/AGENTS.md
"$STALENESS" check >/dev/null 2>&1
check "after write ./dir, editing only the doc is not drift" 0 $?
"$STALENESS" ignore ./tools >/dev/null 2>&1
ig="$(python3 -c 'import json;print(",".join(json.load(open(".claude/house-rules.lock.json")).get("ignore",[])))')"
check_not_contains "ignore ./dir records the normalized key" "./tools" "$ig"
check_contains "the normalized ignore entry is present" "tools" "$ig"

# --- CLAUDE.md is a first-class doc for `write` ------------------------------
# A dir documented only by CLAUDE.md must not get a misleading "no doc" note;
# a dir with neither doc still gets one.

mkdir cldir
printf 'a\n' > cldir/a.py
printf 'b\n' > cldir/b.py
echo doc > cldir/CLAUDE.md
commit_all "$repo" cldir
out="$("$STALENESS" write cldir 2>&1)"
check "write on a CLAUDE.md-documented dir succeeds" 0 $?
check_not_contains "no missing-doc note for a CLAUDE.md dir" "note:" "$out"
mkdir nodoc
printf 'a\n' > nodoc/a.py
commit_all "$repo" nodoc
out="$("$STALENESS" write nodoc 2>&1)"
check_contains "a dir with neither doc still gets the note" "note:" "$out"

# --- File deleted from the worktree without git rm ---------------------------
# Still drift (the file's hash contributes nothing ≠ baseline), and git's
# "fatal: could not open" noise must not leak into the block message.

rm src/a.js
out="$("$STALENESS" check 2>&1)"; rc=$?
check "deleting a tracked file (no git rm) is drift" 1 "$rc"
check_not_contains "the drift message carries no git fatal noise" "fatal" "$out"
git -C "$repo" checkout -- src/a.js
"$STALENESS" check >/dev/null 2>&1
check "restoring the file clears the drift" 0 $?

# --- Multi-dir check: the message must name only the drifted dir -------------

mkdir other
printf 'x\n' > other/x.js
printf 'y\n' > other/y.js
commit_all "$repo" other
"$STALENESS" write other >/dev/null 2>&1
echo change >> src/a.js
out="$("$STALENESS" check 2>&1)"; rc=$?
check "two baselined dirs, drift in one: exit 1" 1 "$rc"
check_contains     "the drifted dir is named" "src/" "$out"
check_not_contains "the clean dir is not mentioned at all" "other/" "$out"
"$STALENESS" write src >/dev/null 2>&1

# --- Symlinked directories: fail closed, never a silent empty hash -----------
# git doesn't traverse into a symlink via a trailing-slash pathspec (it's a
# blob, not a tree), so `git ls-files -- "$dir/"` returns nothing and dir_hash
# would otherwise silently produce the hash of zero files — a baseline that
# can never detect drift, forever. `[ -d ]` alone doesn't catch this (bash
# follows symlinks), so write/hash/check each need an explicit `[ -L ]` check.

ln -s src symlinked_src
out="$("$STALENESS" write symlinked_src 2>&1)"; rc=$?
check "write on a symlinked directory is rejected (exit 2)" 2 "$rc"
check_contains "the rejection names it as a symlink, not a missing dir" "symlink" "$out"
out="$("$STALENESS" hash symlinked_src 2>&1)"; rc=$?
check "hash on a symlinked directory is rejected (exit 2, not a fake empty hash)" 2 "$rc"
check_contains "the rejection message replaces the hash, doesn't precede it" "symlink" "$out"
rm symlinked_src

# A dir already baselined that later *becomes* a symlink must show up as drift
# (same as "directory is gone"), not silently pass because `[ -d ]` still
# says yes for a symlink pointing at a real directory.
mkdir turned_into_link
printf 'a\n' > turned_into_link/a.js
printf 'b\n' > turned_into_link/b.js
commit_all "$repo" turned_into_link
"$STALENESS" write turned_into_link >/dev/null 2>&1
rm -rf turned_into_link
ln -s src turned_into_link
out="$("$STALENESS" check 2>&1)"; rc=$?
check "a baselined dir that became a symlink is reported as drift (exit 1)" 1 "$rc"
check_contains "the message says the directory is gone, not a hash mismatch" "is gone" "$out"
rm turned_into_link

finish
