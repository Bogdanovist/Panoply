#!/usr/bin/env bash
# implement-review-gate.sh — deterministic 2-pass implementer→reviewer gate.
#
# Owns the control flow for the per-phase review loop so the LLM does not.
# Runs the implementer command, then the reviewer command, and reads a
# sentinel file. If the sentinel contents are exactly `REVIEW_APPROVED` the
# gate exits 0. Otherwise it runs a remediation pass (implementer fed the
# first-round findings on stdin, then reviewer again). A second CHANGES
# verdict exits 42 (EX_REVIEW_UNRESOLVED) — the caller drops to interactive.
#
# Contract:
#   --group-id <id>            Suffix for the sentinel path (.review-verdict-<id>).
#                              Omitted → default sentinel `.review-verdict`.
#   --implementer-cmd <cmd>    Shell command executed via `bash -c`. Run twice
#                              at most. The 2nd invocation receives the pass-1
#                              findings on stdin.
#   --reviewer-cmd <cmd>       Shell command executed via `bash -c`. MUST write
#                              the sentinel file to $REVIEW_SENTINEL (exported).
#
# Exit codes:
#   0   PASS on pass 1 or pass 2.
#   42  EX_REVIEW_UNRESOLVED — both passes returned CHANGES.
#   other non-zero  implementer or reviewer crashed; gate surfaces the failure.

set -euo pipefail

EX_REVIEW_UNRESOLVED=42
APPROVAL_TOKEN="REVIEW_APPROVED"
MAX_PASSES=2

GROUP_ID=""
IMPLEMENTER_CMD=""
REVIEWER_CMD=""

usage() {
  cat >&2 <<'USAGE'
Usage: implement-review-gate.sh [--group-id <id>] \
                                --implementer-cmd <cmd> \
                                --reviewer-cmd <cmd>
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --group-id)
      GROUP_ID="${2:-}"; shift 2 ;;
    --implementer-cmd)
      IMPLEMENTER_CMD="${2:-}"; shift 2 ;;
    --reviewer-cmd)
      REVIEWER_CMD="${2:-}"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "gate: unknown argument: $1" >&2
      usage; exit 2 ;;
  esac
done

if [ -z "$IMPLEMENTER_CMD" ] || [ -z "$REVIEWER_CMD" ]; then
  echo "gate: --implementer-cmd and --reviewer-cmd are required" >&2
  usage
  exit 2
fi

# Sentinel path (optionally suffixed by group-id).
if [ -n "$GROUP_ID" ]; then
  SENTINEL=".review-verdict-${GROUP_ID}"
else
  SENTINEL=".review-verdict"
fi
export REVIEW_SENTINEL="$SENTINEL"

# Remove stale sentinel so we never mistake a prior run's verdict for a fresh one.
rm -f -- "$SENTINEL"

# --- pass runner ------------------------------------------------------------

# run_implementer <pass#> [<findings-file>]
run_implementer() {
  local pass_num="$1" findings_file="${2:-}"
  local rc=0
  if [ -n "$findings_file" ] && [ -f "$findings_file" ]; then
    # Feed pass-1 findings to implementer on stdin for the remediation pass.
    bash -c "$IMPLEMENTER_CMD" < "$findings_file" || rc=$?
  else
    bash -c "$IMPLEMENTER_CMD" </dev/null || rc=$?
  fi
  if [ "$rc" -ne 0 ]; then
    echo "gate: implementer command failed on pass ${pass_num} (exit ${rc})" >&2
    exit "$rc"
  fi
}

# run_reviewer <pass#>
run_reviewer() {
  local pass_num="$1"
  local rc=0
  # Sentinel is intentionally deleted before each reviewer run so we can tell
  # the difference between "reviewer wrote APPROVED" and "reviewer crashed".
  rm -f -- "$SENTINEL"
  bash -c "$REVIEWER_CMD" || rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "gate: reviewer command failed on pass ${pass_num} (exit ${rc})" >&2
    exit "$rc"
  fi
  if [ ! -f "$SENTINEL" ]; then
    echo "gate: reviewer on pass ${pass_num} did not write sentinel ${SENTINEL}" >&2
    exit 3
  fi
}

# read_verdict — echoes the raw sentinel contents (stripped of one trailing newline).
read_verdict() {
  # Use a form that tolerates a missing trailing newline without losing data.
  # `cat` prints the file byte-for-byte; we compare exactly to APPROVAL_TOKEN.
  cat -- "$SENTINEL"
}

# --- main -------------------------------------------------------------------

PASS1_FINDINGS="$(mktemp)"
trap 'rm -f "$PASS1_FINDINGS"' EXIT

# Pass 1
run_implementer 1
run_reviewer 1
pass1_verdict="$(read_verdict)"

if [ "$pass1_verdict" = "$APPROVAL_TOKEN" ]; then
  exit 0
fi

# Pass 1 was CHANGES — capture findings, run remediation pass.
printf '%s\n' "$pass1_verdict" > "$PASS1_FINDINGS"

if [ "$MAX_PASSES" -lt 2 ]; then
  # Defensive: MAX_PASSES is a constant but keep the guard explicit.
  echo "--- Review findings (pass 1) ---" >&2
  cat "$PASS1_FINDINGS"
  exit "$EX_REVIEW_UNRESOLVED"
fi

run_implementer 2 "$PASS1_FINDINGS"
run_reviewer 2
pass2_verdict="$(read_verdict)"

if [ "$pass2_verdict" = "$APPROVAL_TOKEN" ]; then
  exit 0
fi

# Cap hit: print both rounds of findings on stdout so the caller can surface them.
echo "--- Review findings (pass 1) ---"
cat "$PASS1_FINDINGS"
echo
echo "--- Review findings (pass 2) ---"
printf '%s\n' "$pass2_verdict"
exit "$EX_REVIEW_UNRESOLVED"
