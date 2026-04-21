---
name: verification-before-completion
description: >
  Evidence-before-claims discipline for implementation completion. Use before
  claiming any work is complete, fixed, or passing. Run verification commands
  and confirm output before making success claims.
---

# Verification Before Completion

Evidence before claims, always. No completion claims without fresh verification.

## The Iron Law

**NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE.**

Every claim must be backed by evidence you just observed. Not evidence from earlier. Not evidence you expect. Evidence
you just saw.

## The Five-Step Gate

Before any completion claim, complete these steps:

### Step 1: Identify

What command proves your claim?

```text
Claim: "Tests pass"
Command: npm test (or project's test command)

Claim: "Build succeeds"
Command: npm run build (or project's build command)

Claim: "Lint is clean"
Command: npm run lint (or project's lint command)

Claim: "Bug is fixed"
Command: The reproduction steps that previously failed
```

### Step 2: Run

Execute the command freshly. Not from cache. Not from memory.

```text
Run the command NOW.
Wait for it to complete.
Do not proceed until finished.
```

### Step 3: Read

Read the COMPLETE output.

```text
- Exit code (0 = success)
- All output lines, not just the last one
- Any warnings (not just errors)
- Summary statistics if provided
```

### Step 4: Verify

Confirm the output supports your claim.

```text
Claim: "Tests pass"
Verify: Exit code 0, "X tests passed", no failures

Claim: "Build succeeds"
Verify: Exit code 0, output files created, no errors

Claim: "Bug is fixed"
Verify: Previous failure no longer occurs
```

### Step 5: Claim

Only NOW make your completion claim.

```text
"Tests pass" - after seeing test output showing success
"Build succeeds" - after seeing build complete without errors
"Implementation complete" - after all verifications pass
```

## Rationalization Red Flags

| Thought | Reality |
|---------|---------|
| "It should pass" | Run it and see |
| "I'm confident it works" | Confidence isn't evidence |
| "I already ran it earlier" | Run it again, freshly |
| "The change was small" | Small changes can break things |
| "I'll verify later" | Verify now or don't claim |
| "The agent said it passed" | Verify agent's claims independently |
| "It worked on my machine" | Run it in the target environment |
| "I'm tired of running tests" | Fatigue doesn't excuse skipping verification |

## Integration with Implement Phase

This skill serves as the final gate before completion claims:

```text
Plan step complete? → Run step verification → Claim step done
Phase complete? → Run phase verification → Claim phase done
Implementation complete? → Run all verifications → Claim done
```

**Never mark a step complete without verification evidence.**

## Anti-Patterns

### Partial Verification

**Wrong**: Run only the test file you changed
**Right**: Run full test suite to catch regressions

### Cached Results

**Wrong**: Trust previous run results
**Right**: Run fresh each time before claiming

### Skipping on Confidence

**Wrong**: "I know this works, no need to verify"
**Right**: Verify anyway, confidence isn't evidence

### Trusting Agent Claims

**Wrong**: Agent said tests pass, so they pass
**Right**: Run tests yourself to verify

### Rushing at End

**Wrong**: Skip verification because you're almost done
**Right**: Final verification is most important

## Checklist Before Completion

- [ ] Identified verification command for the claim
- [ ] Ran command freshly (not cached)
- [ ] Read complete output
- [ ] Exit code confirms success
- [ ] Output matches expectations
- [ ] No warnings or errors ignored
- [ ] Evidence supports the specific claim being made
