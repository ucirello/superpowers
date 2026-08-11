---
name: requesting-code-review
description: Use when completing tasks, implementing major features, or before advancing a target bookmark to verify work meets requirements
---

# Requesting Code Review

Dispatch a code reviewer subagent to catch issues before they cascade. The reviewer gets precisely crafted context for evaluation — never your session's history.

**Core principle:** Review early, review often.

## When to Request Review

**Mandatory:**
- After each task in `superpowers:subagent-driven-development`
- After completing major feature
- Before moving or pushing the target bookmark

**Optional but valuable:**
- When stuck (fresh perspective)
- Before refactoring (baseline check)
- After fixing complex bug

## How to Request

**1. Snapshot the working copy and capture immutable commit IDs:**
```bash
jj status
BASE_REV=${FEATURE_BASE_COMMIT:?"Set FEATURE_BASE_COMMIT to the recorded full feature-base commit ID"}
# If the feature intentionally started from upstream main, use instead: BASE_REV=main@origin
BASE_COMMIT=$(jj log --ignore-working-copy -r "$BASE_REV" --no-graph -T 'commit_id ++ "\n"')
END_COMMIT=$(jj log --ignore-working-copy -r '@' --no-graph -T 'commit_id ++ "\n"')
```

Use the feature base recorded before implementation began. If no feature base was recorded, explicitly use `main@origin` only when it is the actual feature base; do not default to `@-`, which truncates multi-change features. Resolve each endpoint to exactly one full commit ID before dispatch so later change, bookmark, or working-copy movement cannot alter the review range.

**2. Dispatch code reviewer subagent:**

Dispatch a `general-purpose` subagent, filling the template at [code-reviewer.md](code-reviewer.md)

**Placeholders:**
- `{DESCRIPTION}` - Brief summary of what you built
- `{PLAN_OR_REQUIREMENTS}` - What it should do
- `{BASE_COMMIT}` - Starting commit ID
- `{END_COMMIT}` - Ending commit ID

**3. Act on feedback:**
- Fix Critical issues immediately
- Fix Important issues before proceeding
- Note Minor issues for later
- Push back if reviewer is wrong (with reasoning)

## Example

```
[Just completed Task 2: Add verification function]

You: Let me request code review before proceeding.

jj status
BASE_REV=${FEATURE_BASE_COMMIT:?"Set FEATURE_BASE_COMMIT to the recorded full feature-base commit ID"}
BASE_COMMIT=$(jj log --ignore-working-copy -r "$BASE_REV" --no-graph -T 'commit_id ++ "\n"')
END_COMMIT=$(jj log --ignore-working-copy -r '@' --no-graph -T 'commit_id ++ "\n"')

[Dispatch code reviewer subagent]
  DESCRIPTION: Added verifyIndex() and repairIndex() with 4 issue types
  PLAN_OR_REQUIREMENTS: Task 2 from docs/plans/deployment-plan.md
  BASE_COMMIT: a7981ec0d7c80fcb3f03d8a11a4938297e99a225
  END_COMMIT: 3df766133a1ab7c981b35642e37fc0d9a2bbd09a

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
