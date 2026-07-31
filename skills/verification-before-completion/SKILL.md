---
name: verification-before-completion
description: Use when about to claim work is complete, fixed, or passing, before finalizing a change or creating a PR - requires running verification commands and confirming output before making any success claims; evidence before assertions always
---

# Verification Before Completion

## Overview

**Core principle:** Evidence before claims, always.

**Violating the letter of this rule is violating the spirit of this rule.**

## The Iron Law

```
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE
```

If you haven't run the verification command in this message, you cannot claim it passes.

## The Gate Function

```
BEFORE claiming any status or expressing satisfaction:

1. IDENTIFY: What command proves this claim?
2. RUN: Execute the FULL command (fresh, complete)
3. READ: Full output, check exit code, count failures
4. VERIFY: Does output confirm the claim?
   - If NO: State actual status with evidence
   - If YES: State claim WITH evidence
5. ONLY THEN: Make the claim

Skip any step = lying, not verifying
```

## Common Failures

| Claim | Requires | Not Sufficient |
|-------|----------|----------------|
| Tests pass | Test command output: 0 failures | Previous run, "should pass" |
| Linter clean | Linter output: 0 errors | Partial check, extrapolation |
| Build succeeds | Build command: exit 0 | Linter passing, logs look good |
| Bug fixed | Test original symptom: passes | Code changed, assumed fixed |
| Regression test works | Red-green cycle verified | Test passes once |
| Agent completed | Identify its revision with `jj log`; `jj diff -r <revision>` shows the intended changes | Agent reports "success" |
| Requirements met | Line-by-line checklist | Tests passing |

`jj diff` without `-r` inspects only the working-copy revision (`@`). If delegated work is in another revision, locate that revision with `jj log` and inspect it explicitly. Use `jj status` and `jj diff --summary -r @` when verifying the current working-copy change.

## Red Flags - STOP

- Using "should", "probably", "seems to"
- Expressing satisfaction before verification ("Great!", "Perfect!", "Done!", etc.)
- About to move on from a completed change, publish its bookmark, or create a PR without verification
- Trusting agent success reports
- Relying on partial verification
- Thinking "just this once"
- Tired and wanting work over
- **ANY wording implying success without having run verification**

## Rationalization Prevention

| Excuse | Reality |
|--------|---------|
| "Should work now" | RUN the verification |
| "I'm confident" | Confidence ≠ evidence |
| "Just this once" | No exceptions |
| "Linter passed" | Linter ≠ compiler |
| "Agent said success" | Verify independently |
| "I'm tired" | Exhaustion ≠ excuse |
| "Partial check is enough" | Partial proves nothing |
| "Different words so rule doesn't apply" | Spirit over letter |

## Key Patterns

**Tests:**
```
✅ [Run test command] [See: 34/34 pass] "All tests pass"
❌ "Should pass now" / "Looks correct"
```

**Regression tests (TDD Red-Green):**
```
✅ Write → Run (pass) → Revert fix → Run (MUST FAIL) → Restore → Run (pass)
❌ "I've written a regression test" (without red-green verification)
```

**Build:**
```
✅ [Run build] [See: exit 0] "Build passes"
❌ "Linter passed" (linter doesn't check compilation)
```

**Requirements:**
```
✅ Re-read plan → Create checklist → Verify each → Report gaps or completion
❌ "Tests pass, phase complete"
```

**Agent delegation:**
```
✅ Agent reports success → Locate its revision with `jj log` → Check `jj diff -r <revision>` → Verify changes → Report actual state
❌ Trust agent report
```

**Jujutsu change descriptions:**

Before composing, editing, validating, or recommending a Jujutsu change description:

1. At runtime, use `jj --ignore-working-copy workspace root`, `jj --ignore-working-copy file list`, and `jj --ignore-working-copy file show -r @ <path>` to locate the repository root and read every applicable repository instruction file.
2. Inspect relevant change-description history with `jj --ignore-working-copy log`; repository-local standards take precedence.
3. Apply only compatible quality guidance from the Go Commit Message wiki. Do not impose fixed wording, syntax, prefixes, capitalization rules, line-length rules, examples, or templates.
4. Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards.

Use `jj describe` to edit the working-copy change description, then inspect it with `jj --ignore-working-copy log -r @` and verify its content against the actual change with `jj --ignore-working-copy diff -r @`.

**Publication:**

Verify the completed revision and confirm that the bookmark being published targets it. Jujutsu publishes bookmarks and the revisions reachable from them; starting a new working-copy change does not publish or make the previous revision immutable.

**Temporary verification artifacts:**

If verification needs temporary artifacts, place them under `$(jj --ignore-working-copy workspace root)/.tmp`. Before creating them, verify the repository root's ignore rules exclude `.tmp/`; if they do not, stop and add that rule first. If the current directory is not in a Jujutsu workspace, use the local `./.tmp` directory instead. Do not use an OS-global temporary directory. Remove only the exact paths created for the verification after it finishes.

## When To Apply

**ALWAYS before:**
- ANY variation of success/completion claims
- ANY expression of satisfaction
- ANY positive statement about work state
- Moving on from a completed change, publishing its bookmark, PR creation, task completion
- Moving to next task
- Delegating to agents

**Rule applies to:**
- Exact phrases
- Paraphrases and synonyms
- Implications of success
- ANY communication suggesting completion/correctness
