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
- Before advancing the main bookmark

**Optional but valuable:**
- When stuck (fresh perspective)
- Before refactoring (baseline check)
- After fixing complex bug

## How to Request

**1. Get JJ revision IDs and the repository root:**

Record `FROM_REVISION` as a full commit ID before implementation starts so a
multi-change task retains its true base. At review time, use `@` when it contains
completed work; otherwise use the completed parent of the fresh empty change.

```bash
REPOSITORY_ROOT=$(jj workspace root)
FROM_REVISION="$RECORDED_BASE_COMMIT_ID"
TO_REVISION=$(jj --ignore-working-copy log -r 'exactly(coalesce(@ & ~empty(), @-), 1)' --no-graph -T 'commit_id ++ "\n"')
```

**2. Dispatch code reviewer subagent:**

Dispatch a `general-purpose` subagent, filling the template at [code-reviewer.md](code-reviewer.md)

**Placeholders:**
- `{DESCRIPTION}` - Brief summary of what you built
- `{PLAN_OR_REQUIREMENTS}` - What it should do
- `{REPOSITORY_ROOT}` - Root reported by `jj workspace root`
- `{FROM_REVISION}` - Starting revision
- `{TO_REVISION}` - Ending revision

Compose the request from those repository-derived values using this exact sentence:

`Go review the code changes in {REPOSITORY_ROOT} from {FROM_REVISION} to {TO_REVISION}.`

**3. Act on feedback:**
- Fix Critical issues immediately
- Fix Important issues before proceeding
- Note Minor issues for later
- Push back if reviewer is wrong (with reasoning)

## Example

```
[Just completed Task 2: Add verification function]

You: Let me request code review before proceeding.

REPOSITORY_ROOT=$(jj workspace root)
FROM_REVISION="$RECORDED_BASE_COMMIT_ID"
TO_REVISION=$(jj --ignore-working-copy log -r 'exactly(coalesce(@ & ~empty(), @-), 1)' --no-graph -T 'commit_id ++ "\n"')

[Dispatch code reviewer subagent]
  REQUEST: Go review the code changes in ${REPOSITORY_ROOT} from ${FROM_REVISION} to ${TO_REVISION}.
  DESCRIPTION: Added verifyIndex() and repairIndex() with 4 issue types
  PLAN_OR_REQUIREMENTS: Task 2 from docs/rocketclaw/plans/deployment-plan.md
  REPOSITORY_ROOT: ${REPOSITORY_ROOT}
  FROM_REVISION: ${FROM_REVISION}
  TO_REVISION: ${TO_REVISION}

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
