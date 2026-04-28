#!/usr/bin/env bash
# rpi-preflight.sh — git hygiene for the RPI Phase 0 preflight.
#
# Sets up a clean feature branch off an up-to-date base before Phase 1 begins,
# so the user does not have to manage branches by hand. The script never asks
# questions itself — when a situation needs user input it exits with a known
# code, and the orchestrator handles the AskUserQuestion path.
#
# Usage:
#   rpi-preflight.sh --topic <topic-string>
#
# Output:
#   stdout (on exit 0): the resolved branch name (one line, no trailing junk)
#   stdout (on exit 12): the current branch name (so the orchestrator can show
#                        it to the user)
#   stderr: diagnostics
#
# Exit codes:
#   0   Ready. Branch is set up; orchestrator records this as the working
#       branch in the plan's Implementation State section.
#   10  Dirty working tree. Orchestrator AskUserQuestion: stash / commit-first
#       / abort.
#   11  Base branch has diverged from origin (cannot fast-forward and we are
#       not strictly ahead). Orchestrator AskUserQuestion: rebase / hard-reset
#       to origin / abort.
#   12  Currently on a non-base branch. Orchestrator AskUserQuestion: continue
#       on this branch / switch to base and create fresh / abort. Current
#       branch name is printed on stdout.
#   13  Fatal (missing args, not in a repo, fetch failed, etc.). Diagnostics
#       on stderr.

set -euo pipefail

TOPIC=""

while [ $# -gt 0 ]; do
  case "$1" in
    --topic)
      TOPIC="${2:-}"; shift 2 ;;
    -h|--help)
      sed -n '/^# Usage:/,/^# Exit codes:/p' "$0" >&2
      exit 0 ;;
    *)
      echo "preflight: unknown argument: $1" >&2
      exit 13 ;;
  esac
done

if [ -z "$TOPIC" ]; then
  echo "preflight: --topic required" >&2
  exit 13
fi

# Must be in a git repo.
if ! ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  echo "preflight: not a git repository" >&2
  exit 13
fi

CURRENT="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"

# --- Panoply mode -----------------------------------------------------------
# In the Panoply meta-repo, RPI runs on main per the project's own convention
# (see Panoply CLAUDE.md). No branch creation; no PRs; the Stop hook
# auto-commits to main.
if [ "$ROOT" = "$HOME/src/Panoply" ]; then
  if [ "$CURRENT" != "main" ]; then
    echo "preflight: in Panoply but on '$CURRENT' (expected main)" >&2
    echo "preflight: checkout main before running RPI here" >&2
    exit 13
  fi
  if [ -n "$(git status --porcelain)" ]; then
    exit 10
  fi
  echo "main"
  exit 0
fi

# --- Standard mode ----------------------------------------------------------

# Determine base branch from origin/HEAD; fall back to 'main'.
BASE="main"
if BASE_REF="$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null)"; then
  BASE="${BASE_REF#refs/remotes/origin/}"
fi

# Working tree must be clean.
if [ -n "$(git status --porcelain)" ]; then
  exit 10
fi

# If on a non-base branch, defer to the orchestrator.
if [ "$CURRENT" != "$BASE" ]; then
  echo "$CURRENT"
  exit 12
fi

# On the base branch — sync with origin (if there is one) then create a
# feature branch. Local-only repos with no origin are valid; just skip sync.
if git remote get-url origin >/dev/null 2>&1; then
  if ! git fetch origin "$BASE" --quiet 2>/dev/null; then
    echo "preflight: git fetch origin $BASE failed (network or auth?)" >&2
    exit 13
  fi

  LOCAL_SHA="$(git rev-parse "$BASE")"
  REMOTE_SHA="$(git rev-parse "origin/$BASE" 2>/dev/null || echo "")"

  if [ -n "$REMOTE_SHA" ] && [ "$LOCAL_SHA" != "$REMOTE_SHA" ]; then
    if git merge-base --is-ancestor "$LOCAL_SHA" "$REMOTE_SHA"; then
      # Local is behind; fast-forward.
      if ! git pull --ff-only origin "$BASE" --quiet 2>/dev/null; then
        echo "preflight: fast-forward pull failed unexpectedly" >&2
        exit 13
      fi
    elif git merge-base --is-ancestor "$REMOTE_SHA" "$LOCAL_SHA"; then
      # Local is strictly ahead of remote — unusual on $BASE but not blocking.
      :
    else
      # Truly diverged.
      exit 11
    fi
  fi
fi

# Slugify topic: lowercase, non-alphanumerics → '-', collapse, trim.
SLUG="$(printf '%s' "$TOPIC" \
  | tr '[:upper:]' '[:lower:]' \
  | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//')"
if [ -z "$SLUG" ]; then
  echo "preflight: empty slug derived from topic '$TOPIC'" >&2
  exit 13
fi

BRANCH="feat/$SLUG"

# If the branch name already exists, append the short SHA of base HEAD for
# uniqueness rather than refusing or silently reusing.
if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  SHORT="$(git rev-parse --short HEAD)"
  BRANCH="${BRANCH}-${SHORT}"
fi

git checkout -b "$BRANCH" --quiet
echo "$BRANCH"
exit 0
