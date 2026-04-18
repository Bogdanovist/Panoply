#!/usr/bin/env bash
# Pure-bash test harness for implement-review-gate.sh.
# Exercises the externally-observable behaviour enumerated in the plan
# (Phase 1, Step 1.1). No dependency on bats — keeps the harness portable
# across macOS and Linux dev environments.
#
# Each test runs in an isolated temp directory. The gate's implementer
# and reviewer commands are stub shell snippets that simulate the two
# agents and write controlled sentinel contents.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GATE="$SCRIPT_DIR/implement-review-gate.sh"

PASS=0
FAIL=0
FAILED_NAMES=()

color_pass() { printf '\033[32m%s\033[0m' "$1"; }
color_fail() { printf '\033[31m%s\033[0m' "$1"; }

run_test() {
  local name="$1"; shift
  local tmpdir
  tmpdir="$(mktemp -d)"
  pushd "$tmpdir" >/dev/null
  # Export the tmpdir for stub scripts to use as scratch state.
  export GATE_TEST_TMP="$tmpdir"
  local out
  local rc=0
  if out="$("$@" 2>&1)"; then
    rc=0
  else
    rc=$?
  fi
  export LAST_OUTPUT="$out"
  export LAST_RC="$rc"
  popd >/dev/null
  # Leave tmpdir for debugging on failure; clean on success.
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
# Stub generators — write implementer/reviewer scripts into cwd.
# ---------------------------------------------------------------

# Reviewer stub: writes $1 to the sentinel path passed in via
# REVIEW_SENTINEL env var. Argument is the contents string.
make_reviewer_stub() {
  local sentinel_contents="$1"
  local path="$GATE_TEST_TMP/reviewer_stub.sh"
  cat > "$path" <<EOF
#!/usr/bin/env bash
set -euo pipefail
# Count invocations via a side-effect file.
echo x >> "\$GATE_TEST_TMP/reviewer.calls"
printf '%s' "$sentinel_contents" > "\$REVIEW_SENTINEL"
EOF
  chmod +x "$path"
  echo "$path"
}

# Reviewer stub that writes different content per invocation.
make_reviewer_sequence_stub() {
  local first="$1" second="$2"
  local path="$GATE_TEST_TMP/reviewer_stub.sh"
  cat > "$path" <<EOF
#!/usr/bin/env bash
set -euo pipefail
echo x >> "\$GATE_TEST_TMP/reviewer.calls"
count=\$(wc -l < "\$GATE_TEST_TMP/reviewer.calls" | tr -d ' ')
if [ "\$count" = "1" ]; then
  printf '%s' "$first" > "\$REVIEW_SENTINEL"
else
  printf '%s' "$second" > "\$REVIEW_SENTINEL"
fi
EOF
  chmod +x "$path"
  echo "$path"
}

# Implementer stub: records invocation and any stdin input.
make_implementer_stub() {
  local path="$GATE_TEST_TMP/implementer_stub.sh"
  cat > "$path" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo x >> "$GATE_TEST_TMP/implementer.calls"
# Capture stdin if any (pass-2 feedback payload).
cat > "$GATE_TEST_TMP/implementer.stdin.$(wc -l < "$GATE_TEST_TMP/implementer.calls" | tr -d ' ')"
EOF
  chmod +x "$path"
  echo "$path"
}

# Implementer stub that fails on first invocation.
make_implementer_failing_stub() {
  local path="$GATE_TEST_TMP/implementer_stub.sh"
  cat > "$path" <<'EOF'
#!/usr/bin/env bash
echo x >> "$GATE_TEST_TMP/implementer.calls"
exit 1
EOF
  chmod +x "$path"
  echo "$path"
}

# Reviewer stub that crashes.
make_reviewer_failing_stub() {
  local path="$GATE_TEST_TMP/reviewer_stub.sh"
  cat > "$path" <<'EOF'
#!/usr/bin/env bash
echo x >> "$GATE_TEST_TMP/reviewer.calls"
exit 1
EOF
  chmod +x "$path"
  echo "$path"
}

impl_call_count() {
  [ -f "$GATE_TEST_TMP/implementer.calls" ] || { echo 0; return; }
  wc -l < "$GATE_TEST_TMP/implementer.calls" | tr -d ' '
}
reviewer_call_count() {
  [ -f "$GATE_TEST_TMP/reviewer.calls" ] || { echo 0; return; }
  wc -l < "$GATE_TEST_TMP/reviewer.calls" | tr -d ' '
}

# ---------------------------------------------------------------
# Test cases
# ---------------------------------------------------------------

test_pass_on_first_review() {
  local impl reviewer
  impl="$(make_implementer_stub)"
  reviewer="$(make_reviewer_stub 'REVIEW_APPROVED')"
  "$GATE" --implementer-cmd "$impl" --reviewer-cmd "$reviewer"
}
verify_pass_on_first_review() {
  [ "$LAST_RC" = "0" ] || return 1
  [ "$(impl_call_count)" = "1" ] || return 1
  [ "$(reviewer_call_count)" = "1" ] || return 1
}

test_pass_on_second_review() {
  local impl reviewer
  impl="$(make_implementer_stub)"
  reviewer="$(make_reviewer_sequence_stub '- fix the bug on line 42' 'REVIEW_APPROVED')"
  "$GATE" --implementer-cmd "$impl" --reviewer-cmd "$reviewer"
}
verify_pass_on_second_review() {
  [ "$LAST_RC" = "0" ] || return 1
  [ "$(impl_call_count)" = "2" ] || return 1
  [ "$(reviewer_call_count)" = "2" ] || return 1
  # The 2nd implementer call must have received the pass-1 findings on stdin.
  [ -f "$GATE_TEST_TMP/implementer.stdin.2" ] || return 1
  grep -q 'line 42' "$GATE_TEST_TMP/implementer.stdin.2" || return 1
}

test_cap_hit_exits_42() {
  local impl reviewer
  impl="$(make_implementer_stub)"
  reviewer="$(make_reviewer_sequence_stub '- first round issue' '- second round issue')"
  "$GATE" --implementer-cmd "$impl" --reviewer-cmd "$reviewer"
}
verify_cap_hit_exits_42() {
  [ "$LAST_RC" = "42" ] || return 1
  [ "$(impl_call_count)" = "2" ] || return 1
  [ "$(reviewer_call_count)" = "2" ] || return 1
  # Both rounds of findings surface on stdout.
  echo "$LAST_OUTPUT" | grep -q 'first round issue' || return 1
  echo "$LAST_OUTPUT" | grep -q 'second round issue' || return 1
}

test_group_id_suffix() {
  local impl reviewer
  impl="$(make_implementer_stub)"
  reviewer="$(make_reviewer_stub 'REVIEW_APPROVED')"
  "$GATE" --group-id foo --implementer-cmd "$impl" --reviewer-cmd "$reviewer"
}
verify_group_id_suffix() {
  [ "$LAST_RC" = "0" ] || return 1
  # The reviewer stub writes to $REVIEW_SENTINEL; after exit 0 the gate
  # does not delete the sentinel, so we can verify the path was correct.
  [ -f "$GATE_TEST_TMP/.review-verdict-foo" ] || return 1
  # Default-path sentinel must NOT exist.
  [ ! -f "$GATE_TEST_TMP/.review-verdict" ] || return 1
}

test_default_sentinel_path() {
  local impl reviewer
  impl="$(make_implementer_stub)"
  reviewer="$(make_reviewer_stub 'REVIEW_APPROVED')"
  "$GATE" --implementer-cmd "$impl" --reviewer-cmd "$reviewer"
}
verify_default_sentinel_path() {
  [ "$LAST_RC" = "0" ] || return 1
  [ -f "$GATE_TEST_TMP/.review-verdict" ] || return 1
}

test_stale_sentinel_removed() {
  # Pre-seed a stale sentinel with old content; gate must delete before pass 1.
  printf 'STALE_CONTENT' > "$GATE_TEST_TMP/.review-verdict"
  local impl reviewer
  impl="$(make_implementer_stub)"
  reviewer="$(make_reviewer_stub 'REVIEW_APPROVED')"
  "$GATE" --implementer-cmd "$impl" --reviewer-cmd "$reviewer"
}
verify_stale_sentinel_removed() {
  [ "$LAST_RC" = "0" ] || return 1
  # Sentinel should now contain REVIEW_APPROVED, not STALE_CONTENT.
  local contents
  contents="$(cat "$GATE_TEST_TMP/.review-verdict")"
  [ "$contents" = "REVIEW_APPROVED" ] || return 1
}

test_implementer_failure() {
  local impl reviewer
  impl="$(make_implementer_failing_stub)"
  reviewer="$(make_reviewer_stub 'REVIEW_APPROVED')"
  "$GATE" --implementer-cmd "$impl" --reviewer-cmd "$reviewer"
}
verify_implementer_failure() {
  # Distinct non-zero exit code, NOT 0 and NOT 42.
  [ "$LAST_RC" != "0" ] || return 1
  [ "$LAST_RC" != "42" ] || return 1
  # Reviewer must NOT have been called.
  [ "$(reviewer_call_count)" = "0" ] || return 1
  # Error message mentions the implementer.
  echo "$LAST_OUTPUT" | grep -qi 'implementer' || return 1
}

test_reviewer_failure() {
  local impl reviewer
  impl="$(make_implementer_stub)"
  reviewer="$(make_reviewer_failing_stub)"
  "$GATE" --implementer-cmd "$impl" --reviewer-cmd "$reviewer"
}
verify_reviewer_failure() {
  [ "$LAST_RC" != "0" ] || return 1
  [ "$LAST_RC" != "42" ] || return 1
  echo "$LAST_OUTPUT" | grep -qi 'reviewer' || return 1
}

# ---------------------------------------------------------------
# Runner
# ---------------------------------------------------------------

echo "Running implement-review-gate.sh tests..."
echo

run_test pass_on_first_review test_pass_on_first_review
run_test pass_on_second_review test_pass_on_second_review
run_test cap_hit_exits_42 test_cap_hit_exits_42
run_test group_id_suffix test_group_id_suffix
run_test default_sentinel_path test_default_sentinel_path
run_test stale_sentinel_removed test_stale_sentinel_removed
run_test implementer_failure test_implementer_failure
run_test reviewer_failure test_reviewer_failure

echo
echo "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
  echo "Failed: ${FAILED_NAMES[*]}"
  exit 1
fi
exit 0
