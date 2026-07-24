---
name: requesting-code-review
description: Use when completing tasks, implementing major features, or before integration to verify work meets requirements
---

# Requesting Code Review

Dispatch a code reviewer subagent to catch issues before they cascade. The reviewer gets precisely crafted context for evaluation — never your session's history.

**Core principle:** Review early, review often.

## When to Request Review

**Mandatory:**
- After each task in subagent-driven development
- After completing major feature
- Before integrating changes into the target bookmark

**Optional but valuable:**
- When stuck (fresh perspective)
- Before refactoring (baseline check)
- After fixing complex bug

## How to Request

**1. Choose the Jujutsu revision range:**
```bash
jj status  # Snapshot the current working copy before resolving endpoints.
# For a completed change after `jj commit`; use @- and @ for unfinished work.
BASE_REV=$(jj log --no-graph -r '@--' -T 'commit_id ++ "\n"')  # or resolve main@origin
END_REV=$(jj log --no-graph -r '@-' -T 'commit_id ++ "\n"')
```

Pass immutable commit IDs to the reviewer so its read-only `--ignore-working-copy` commands inspect the snapshotted endpoints exactly. Local instructions and repository history take precedence.

**2. Dispatch code reviewer subagent:**

Dispatch a `general-purpose` subagent, filling the template at [code-reviewer.md](code-reviewer.md)

**Placeholders:**
- `{DESCRIPTION}` - Brief summary of what you built
- `{PLAN_OR_REQUIREMENTS}` - What it should do
- `{BASE_REV}` - Starting revision
- `{END_REV}` - Ending revision

**3. Act on feedback:**
- Fix Critical issues immediately
- Fix Important issues before proceeding
- Note Minor issues for later
- Push back if reviewer is wrong (with reasoning)

When feedback composes, edits, validates, or recommends a change description: Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards. Inspect repository history with `jj log` at runtime. Repository-local commit-message syntax as established by project instructions and observed history ALWAYS wins when it differs from the Go guidance. Apply compatible Go guidance to message quality, clarity, and structure without replacing repository-local syntax. Use `jj describe -m "<description composed from the standards above>"` when editing a description.

## Example

```
[Just completed Task 2: Add verification function]

You: Let me request code review before proceeding.

BASE_REV=<resolved parent revision>
END_REV=<resolved completed revision>

[Dispatch code reviewer subagent]
  DESCRIPTION: Implemented verifyIndex() and repairIndex()
  PLAN_OR_REQUIREMENTS: Task 2 from the implementation plan
  BASE_REV: [Resolved parent revision]
  END_REV: [Resolved completed revision]

[Subagent returns]:
  Strengths: Clean architecture, real tests
  Issues:
    Important: Missing progress indicators
    Minor: Magic number (100) for reporting interval
  Assessment: Ready to proceed

You: [Fix progress indicators]
[Continue to Task 3]
```

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "I'll just review the diff myself instead of dispatching a reviewer" | You're the coordinator — reviewing the diff inline burns the context window you need to keep driving the work. Dispatch a reviewer subagent: the diff and the evaluation live in its context, and only the findings come back to you. |
| "The reviewer needs my whole session history to understand the change" | Hand it precisely crafted context, never your session's history. That keeps the reviewer on the work product, not your thought process. |

## Red Flags

**Never:**
- Skip review because "it's simple"
- Ignore Critical issues
- Proceed with unfixed Important issues
- Argue with valid technical feedback

**If reviewer wrong:**
- Push back with technical reasoning
- Show code/tests that prove it works
- Request clarification

See template at: [code-reviewer.md](code-reviewer.md)
