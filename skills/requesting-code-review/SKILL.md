---
name: requesting-code-review
description: Use when completing tasks, implementing major features, or before merging to verify work meets requirements
---

# Requesting Code Review

Dispatch a code reviewer subagent to catch issues before they cascade. The reviewer gets precisely crafted context for evaluation — never your session's history.

**Core principle:** Review early, review often.

## When to Request Review

**Mandatory:**
- After each task in subagent-driven development
- After completing major feature
- Before advancing the `main` bookmark

**Optional but valuable:**
- When stuck (fresh perspective)
- Before refactoring (baseline check)
- After fixing complex bug

## How to Request

**1. Get jj revision IDs:**

Choose the starting revision from the plan, task boundary, or known base
bookmark. It must resolve to exactly one revision. Use `@-` only after
confirming that the working-copy change has one parent; a merge change can
have multiple parents and requires an explicitly selected review base.

```bash
BASE_REVSET=<plan-task-or-bookmark-base>
[ "$(jj log --no-graph -r "$BASE_REVSET" -T 'commit_id ++ "\n"' | wc -l | tr -d ' ')" -eq 1 ] || { printf 'review base must resolve to one revision\n' >&2; exit 1; }
BASE_REVISION=$(jj log --no-graph -r "$BASE_REVSET" -T 'commit_id ++ "\n"')
END_REVISION=$(jj log --no-graph -r '@' -T 'commit_id ++ "\n"')
```

**2. Dispatch code reviewer subagent:**

Dispatch a `general-purpose` subagent, filling the template at [code-reviewer.md](code-reviewer.md)

**Placeholders:**
- `{DESCRIPTION}` - Brief summary of what you built
- `{PLAN_OR_REQUIREMENTS}` - What it should do
- `{BASE_REVISION}` - Starting revision
- `{END_REVISION}` - Ending revision

**3. Act on feedback:**
- Fix Critical issues immediately
- Fix Important issues before proceeding
- Note Minor issues for later
- Push back if reviewer is wrong (with reasoning)

## Example

```
[Just completed Task 2: Add verification function]

You: Let me request code review before proceeding.

BASE_REVSET=<Task-2-starting-revision>
BASE_REVISION=$(jj log --no-graph -r "$BASE_REVSET" -T 'commit_id ++ "\n"')
END_REVISION=$(jj log --no-graph -r '@' -T 'commit_id ++ "\n"')

[Dispatch code reviewer subagent]
  DESCRIPTION: Added verifyIndex() and repairIndex() with 4 issue types
  PLAN_OR_REQUIREMENTS: Task 2 from docs/plans/deployment-plan.md
  BASE_REVISION: a7981ec
  END_REVISION: 3df7661

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
