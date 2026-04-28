#!/usr/bin/env bash
# Pure-bash test harness for rpi-preflight.sh.
# Each test runs in an isolated temp directory containing its own git repo
# and (when needed) a fake "remote" repo. No network. No dependency on bats.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PREFLIGHT="$SCRIPT_DIR/rpi-preflight.sh"

PASS=0
FAIL=0
FAILED_NAMES=()

color_pass() { printf '\033[32m%s\033[0m' "$1"; }
color_fail() { printf '\033[31m%s\033[0m' "$1"; }

# Run a test function in a fresh tmpdir. The function defines `setup` and
# `verify` inline; the harness handles cd, capture, and reporting.
run_test() {
  local name="$1"
  local tmpdir
  tmpdir="$(mktemp -d)"
  pushd "$tmpdir" >/dev/null

  local out=""
  local rc=0
  if out="$(eval "scenario_$name" 2>&1)"; then
    rc=0
  else
    rc=$?
  fi
  export LAST_OUTPUT="$out"
  export LAST_RC="$rc"

  popd >/dev/null

  if eval "verify_$name"; then
    PASS=$((PASS+1))
    printf '  %s %s\n' "$(color_pass PASS)" "$name"
    rm -rf "$tmpdir"
  else
    FAIL=$((FAIL+1))
    FAILED_NAMES+=("$name")
    printf '  %s %s\n    tmpdir: %s\n    rc=%s\n    out: %s\n' \
      "$(color_fail FAIL)" "$name" "$tmpdir" "$rc" "$out"
  fi
}

# ---------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------

# Initialise a repo with one commit on `main`. Configure git identity locally
# so commits succeed in environments without a global identity.
init_repo() {
  git init -q -b main .
  git config user.email "test@example.com"
  git config user.name "Test"
  echo "hello" > README.md
  git add README.md
  git commit -q -m "initial"
}

# Set up a bare "remote" repo and wire it as origin, mirroring main.
attach_origin() {
  local remote="$1"
  git init -q --bare "$remote"
  git remote add origin "$remote"
  git push -q -u origin main
  git remote set-head origin main >/dev/null 2>&1 || true
}

# ---------------------------------------------------------------
# Scenarios — each prints the LAST_OUTPUT and exits with LAST_RC.
# ---------------------------------------------------------------

# Missing --topic → exit 13.
scenario_missing_topic() {
  init_repo
  "$PREFLIGHT"
}
verify_missing_topic() {
  [ "$LAST_RC" = "13" ]
}

# Not in a git repo → exit 13.
scenario_not_in_repo() {
  # Empty tmpdir, no init.
  "$PREFLIGHT" --topic foo
}
verify_not_in_repo() {
  [ "$LAST_RC" = "13" ]
}

# Clean working tree on base, no remote configured → exit 0, branch printed.
scenario_clean_on_base_no_remote() {
  init_repo
  "$PREFLIGHT" --topic "Add caching to user lookup"
}
verify_clean_on_base_no_remote() {
  [ "$LAST_RC" = "0" ] && [ "$LAST_OUTPUT" = "feat/add-caching-to-user-lookup" ]
}

# Dirty working tree → exit 10, no branch printed.
scenario_dirty_tree() {
  init_repo
  echo "uncommitted" > scratch.txt
  "$PREFLIGHT" --topic foo
}
verify_dirty_tree() {
  [ "$LAST_RC" = "10" ]
}

# On a non-base branch → exit 12 with current branch name on stdout.
scenario_on_non_base_branch() {
  init_repo
  git checkout -q -b some-feature
  "$PREFLIGHT" --topic foo
}
verify_on_non_base_branch() {
  [ "$LAST_RC" = "12" ] && [ "$LAST_OUTPUT" = "some-feature" ]
}

# Branch already exists → script appends short SHA, exits 0.
scenario_branch_collision() {
  init_repo
  # Pre-create the branch the slug would produce, then go back to main clean.
  git branch feat/foo
  "$PREFLIGHT" --topic foo
}
verify_branch_collision() {
  [ "$LAST_RC" = "0" ] && [[ "$LAST_OUTPUT" =~ ^feat/foo-[0-9a-f]{7,}$ ]]
}

# Local is behind remote (FF possible) → script pulls and creates branch.
scenario_remote_ahead_ff() {
  local remote
  remote="$(mktemp -d)/origin.git"
  init_repo
  attach_origin "$remote"
  # Create a second commit upstream by cloning, committing, pushing.
  local clone
  clone="$(mktemp -d)"
  git clone -q "$remote" "$clone"
  ( cd "$clone" \
    && git config user.email "u@example.com" \
    && git config user.name "U" \
    && echo extra >> README.md \
    && git commit -q -am "second" \
    && git push -q origin main )
  # Local is still at the first commit — FF should succeed.
  "$PREFLIGHT" --topic bar
}
verify_remote_ahead_ff() {
  [ "$LAST_RC" = "0" ] && [ "$LAST_OUTPUT" = "feat/bar" ]
}

# Local and remote diverged → exit 11.
scenario_diverged() {
  local remote
  remote="$(mktemp -d)/origin.git"
  init_repo
  attach_origin "$remote"
  # Push a commit upstream from a clone…
  local clone
  clone="$(mktemp -d)"
  git clone -q "$remote" "$clone"
  ( cd "$clone" \
    && git config user.email "u@example.com" \
    && git config user.name "U" \
    && echo extra >> README.md \
    && git commit -q -am "remote" \
    && git push -q origin main )
  # …and a different commit locally on main.
  echo local > local.txt
  git add local.txt
  git commit -q -m "local"
  "$PREFLIGHT" --topic baz
}
verify_diverged() {
  [ "$LAST_RC" = "11" ]
}

# ---------------------------------------------------------------
# Run all scenarios.
# ---------------------------------------------------------------

echo "Running rpi-preflight.sh tests…"

run_test missing_topic
run_test not_in_repo
run_test clean_on_base_no_remote
run_test dirty_tree
run_test on_non_base_branch
run_test branch_collision
run_test remote_ahead_ff
run_test diverged

echo
echo "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
  printf '  Failed: %s\n' "${FAILED_NAMES[*]}"
  exit 1
fi
