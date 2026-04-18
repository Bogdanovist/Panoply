#!/bin/bash
# pr-preflight-gate.sh — PreToolUse hook on Bash
# Blocks `gh pr create` invocations unless a fresh pr-preflight sentinel exists.
#
# Contract (per docs/plans/2026-04-18-deterministic-review-loop-plan.md, Phase 5):
#   - Sentinel file: `.pr-preflight-passed` at the repo root
#   - Staleness: mtime must be within the last 900 seconds (15 minutes)
#   - Escape hatch: env var PR_PREFLIGHT_SKIP=1 → allow, log to ~/.claude/logs/pr-preflight-skips.log
#   - On missing/stale sentinel: exit 2 with a stderr message telling Claude to run `pr-preflight`

set -euo pipefail

STALENESS_SECONDS=900
LOG_DIR="${HOME}/.claude/logs"
LOG_FILE="${LOG_DIR}/pr-preflight-skips.log"

# Read the tool input from stdin
INPUT=$(cat)

# Only check Bash tool calls
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || true)
if [[ "$TOOL_NAME" != "Bash" ]]; then
  exit 0
fi

COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
if [[ -z "$COMMAND" ]]; then
  exit 0
fi

# Detect `gh pr create`. Handles:
#   - leading whitespace and shell separators (;, &&, ||, |, `, ()
#   - quoted variants: "gh" pr create, 'gh' pr create
#   - absolute paths: /opt/homebrew/bin/gh pr create
#   - word boundary: `gh pr createsomething` must NOT match
#
# Strategy: strip all single/double quotes from the command, then match
# a word-boundaried `[path/]gh pr create` token. Stripping quotes is safer
# than trying to embed both quote types inside a bash-regex character class.
NORM="${COMMAND//\"/}"
NORM="${NORM//\'/}"

GH_PR_CREATE_RE='(^|[[:space:]\;\&\|\`\(])([^[:space:]]*/)?gh[[:space:]]+pr[[:space:]]+create([[:space:]]|$|\;|\&|\||\`|\))'

if ! [[ "$NORM" =~ $GH_PR_CREATE_RE ]]; then
  exit 0
fi

# Escape hatch
if [[ "${PR_PREFLIGHT_SKIP:-}" == "1" ]]; then
  mkdir -p "$LOG_DIR"
  TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  CWD=$(pwd)
  printf '%s\tcwd=%s\tcmd=%s\n' "$TS" "$CWD" "$COMMAND" >>"$LOG_FILE"
  exit 0
fi

# Resolve repo root (fallback to CWD if not in a git repo)
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
SENTINEL="${REPO_ROOT}/.pr-preflight-passed"

# Portable mtime (epoch seconds): macOS `stat -f %m`, Linux `stat -c %Y`
get_mtime() {
  local f="$1"
  if stat -f %m "$f" 2>/dev/null; then
    return 0
  fi
  stat -c %Y "$f" 2>/dev/null
}

block() {
  local reason="$1"
  # Use the structured JSON "block" form, matching gws-write-guard.sh's pattern.
  # Exit 0 after printing the JSON so Claude sees the block reason cleanly.
  printf '{"decision":"block","reason":%s}\n' \
    "$(printf '%s' "$reason" | jq -Rs .)"
  exit 0
}

if [[ ! -f "$SENTINEL" ]]; then
  block "pr-preflight sentinel missing at ${SENTINEL}. Run the \`pr-preflight\` skill first; it will write the sentinel on a PASS verdict. To override in rare cases, re-run with PR_PREFLIGHT_SKIP=1 (logged to ${LOG_FILE})."
fi

MTIME=$(get_mtime "$SENTINEL" || echo 0)
NOW=$(date +%s)
AGE=$((NOW - MTIME))

if (( AGE > STALENESS_SECONDS )); then
  block "pr-preflight sentinel is stale (age ${AGE}s > ${STALENESS_SECONDS}s). Re-run the \`pr-preflight\` skill to refresh ${SENTINEL}, or override with PR_PREFLIGHT_SKIP=1 (logged)."
fi

# Fresh sentinel — allow the command
exit 0
