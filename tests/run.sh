#!/usr/bin/env bash
# Run every per-mode test file. Exit non-zero if any fails.
set -u
TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"

total_fail=0
for t in "$TESTS_DIR"/*.test.sh; do
  echo "== $(basename "$t")"
  if ! bash "$t"; then
    total_fail=$((total_fail + 1))
  fi
done

echo
if [ "$total_fail" -eq 0 ]; then
  echo "ALL TEST FILES PASSED"
else
  echo "$total_fail TEST FILE(S) FAILED"
  exit 1
fi
