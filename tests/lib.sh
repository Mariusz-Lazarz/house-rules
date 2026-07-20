#!/usr/bin/env bash
# Shared helpers for house-rules tests. Deliberately bash 3.2 compatible
# (no mapfile, no associative arrays) — the same floor the scripts target.

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$TESTS_DIR/../skills/house-rules/scripts"
STALENESS="$SCRIPTS_DIR/staleness.sh"
BACKFILL="$SCRIPTS_DIR/staleness-backfill.sh"

PASS=0
FAIL=0

# check <description> <expected-exit> <actual-exit>
check() {
  if [ "$2" = "$3" ]; then
    PASS=$((PASS + 1)); echo "  ok:   $1"
  else
    FAIL=$((FAIL + 1)); echo "  FAIL: $1 (expected exit $2, got $3)"
  fi
}

# check_contains <description> <needle> <haystack>
check_contains() {
  case "$3" in
    *"$2"*) PASS=$((PASS + 1)); echo "  ok:   $1" ;;
    *)      FAIL=$((FAIL + 1)); echo "  FAIL: $1 (output lacks: $2)" ;;
  esac
}

# check_not_contains <description> <needle> <haystack>
check_not_contains() {
  case "$3" in
    *"$2"*) FAIL=$((FAIL + 1)); echo "  FAIL: $1 (output unexpectedly has: $2)" ;;
    *)      PASS=$((PASS + 1)); echo "  ok:   $1" ;;
  esac
}

# make_repo — create a throwaway git repo, print its path
make_repo() {
  local d
  d="$(mktemp -d)"
  git -C "$d" init -q
  git -C "$d" config user.email test@example.invalid
  git -C "$d" config user.name test
  echo "$d"
}

# commit_all <repo> <msg>
commit_all() {
  git -C "$1" add -A
  git -C "$1" commit -q -m "$2"
}

finish() {
  echo "  -- passed $PASS, failed $FAIL"
  [ "$FAIL" -eq 0 ]
}
