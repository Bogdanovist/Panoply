#!/usr/bin/env bash
# Fixture reviewer: flags an issue on both passes to force cap-hit.
set -euo pipefail
counter="$(dirname "$REVIEW_SENTINEL")/.fixture-count"
n=0
[ -f "$counter" ] && n="$(cat "$counter")"
n=$((n + 1))
printf '%s' "$n" > "$counter"
printf -- '- still broken on line 42 (pass %s)\n' "$n" > "$REVIEW_SENTINEL"
