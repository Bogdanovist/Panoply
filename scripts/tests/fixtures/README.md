# Gate fixtures

Minimal fixtures for exercising `implement-review-gate.sh` end-to-end.

- `clean-diff.sh` — simulates a code-reviewer invocation that finds a clean
  diff. Writes `REVIEW_APPROVED` to `$REVIEW_SENTINEL`. Use as the reviewer
  command to verify the one-pass PASS lifecycle.
- `defective-then-clean.sh` — simulates a code-reviewer that flags an issue
  on pass 1, then accepts the remediation on pass 2. Uses a counter file
  (`$GATE_TEST_TMP/fixture.count`) to differentiate invocations. Verifies
  the two-pass PASS lifecycle.
- `persistent-defect.sh` — simulates a reviewer that flags an issue both
  passes. Verifies the cap-hit (exit 42) lifecycle.

Each fixture is a self-contained shell script so it can be wired into
`implement-review-gate.sh --reviewer-cmd` without requiring a live
`claude -p` subagent.
