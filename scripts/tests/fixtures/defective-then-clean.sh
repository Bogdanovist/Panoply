#!/usr/bin/env bash
# Fixture reviewer: flags an issue on pass 1, approves on pass 2.
# Uses a counter file alongside the sentinel path for state.
set -euo pipefail
counter="$(dirname "$REVIEW_SENTINEL")/.fixture-count"
n=0
[ -f "$counter" ] && n="$(cat "$counter")"
n=$((n + 1))
printf '%s' "$n" > "$counter"
if [ "$n" = "1" ]; then
  printf -- '- off-by-one in foo()\n- missing null check on bar\n' > "$REVIEW_SENTINEL"
else
  printf 'REVIEW_APPROVED' > "$REVIEW_SENTINEL"
fi
