#!/usr/bin/env bash
# Fixture reviewer: always writes REVIEW_APPROVED.
set -euo pipefail
printf 'REVIEW_APPROVED' > "$REVIEW_SENTINEL"
