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
- Before integration into the project trunk

**Optional but valuable:**
- When stuck (fresh perspective)
- Before refactoring (baseline check)
- After fixing complex bug

## How to Request

**1. Identify the Jujutsu revisions:**
```bash
BASE_REVISION=$(jj --ignore-working-copy log --no-graph -r 'first_parent(@)' -T 'change_id ++ "\n"')  # or trunk()
TIP_REVISION=$(jj --ignore-working-copy log --no-graph -r '@' -T 'change_id ++ "\n"')
```

`@` is the working-copy commit in the current workspace. Prefer change IDs for review endpoints because they remain associated with a change when its commit is rewritten; a bookmark such as `trunk()` or an unambiguous commit ID is also a valid revision.

**2. Dispatch a general-purpose code reviewer subagent:**

Dispatch a code reviewer subagent, filling the template at [code-reviewer.md](code-reviewer.md)

**Placeholders:**
- `{DESCRIPTION}` - Brief summary of what you built
- `{PLAN_OR_REQUIREMENTS}` - What it should do
- `{BASE_REVISION}` - Starting revision whose file contents form the comparison base
- `{TIP_REVISION}` - Ending revision whose file contents are being reviewed

**3. Act on feedback:**
- Fix Critical issues immediately
- Fix Important issues before proceeding
- Note Minor issues for later
- Push back if reviewer is wrong (with reasoning)

## Example

```
[Just completed Task 2: Add verification function]

You: Let me request code review before proceeding.

jj --ignore-working-copy log -r '::@'  # locate the earlier change by description
BASE_REVISION=<task-1-change-id>
TIP_REVISION=$(jj --ignore-working-copy log --no-graph -r '@' -T 'change_id ++ "\n"')

[Dispatch code reviewer subagent]
  DESCRIPTION: Added verifyIndex() and repairIndex() with 4 issue types
  PLAN_OR_REQUIREMENTS: Task 2 from docs/rocketclaw/plans/deployment-plan.md
  BASE_REVISION: <task-1-change-id>
  TIP_REVISION: <task-2-change-id>

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
