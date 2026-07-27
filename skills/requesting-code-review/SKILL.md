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
- Before merge to main

**Optional but valuable:**
- When stuck (fresh perspective)
- Before refactoring (baseline check)
- After fixing complex bug

## How to Request

**1. Choose jj review boundaries:**
```bash
if [ "$(jj log --no-graph -r @ -T 'if(empty && !description, "yes", "no")')" = yes ]; then
  BASE_REVISION=$(jj log --no-graph -r '@--' -T 'commit_id ++ "\n"')
  HEAD_REVISION=$(jj log --no-graph -r '@-' -T 'commit_id ++ "\n"')
else
  BASE_REVISION=$(jj log --no-graph -r '@-' -T 'commit_id ++ "\n"')
  HEAD_REVISION=$(jj log --no-graph -r '@' -T 'commit_id ++ "\n"')
fi
```

These commit IDs pin the exact snapshots being reviewed. If the intended work spans another range, select its base and head explicitly instead of assuming the adjacent revisions. Confirm the selected history with `jj log -r "$BASE_REVISION..$HEAD_REVISION"`; this revset includes revisions reachable from the head but not the base. Review the aggregate file delta with `jj diff --from "$BASE_REVISION" --to "$HEAD_REVISION"`, not `jj diff -r "$BASE_REVISION..$HEAD_REVISION"`, which shows the individual changes in the revset.

**2. Dispatch code reviewer subagent:**

Dispatch a `general-purpose` subagent, filling the template at [code-reviewer.md](code-reviewer.md)

**Placeholders:**
- `{IMPLEMENTATION_SUMMARY}` - Brief summary of what you built
- `{PLAN_OR_REQUIREMENTS}` - What it should do
- `{BASE_REVISION}` - Starting jj change ID, commit ID, bookmark, or other revision expression
- `{HEAD_REVISION}` - Ending jj change ID, commit ID, bookmark, or other revision expression

**3. Act on feedback:**
- Fix Critical issues immediately
- Fix Important issues before proceeding
- Note Minor issues for later
- Push back if reviewer is wrong (with reasoning)

## Example

```
[Just completed Task 2: Add verification function]

You: Let me request code review before proceeding.

jj log -r '::@'  # inspect history and select the intended completed task
BASE_REVISION=<commit-id-before-task>
HEAD_REVISION=<commit-id-at-task-tip>

[Dispatch code reviewer subagent]
  IMPLEMENTATION_SUMMARY: Added verifyIndex() and repairIndex() with 4 issue types
  PLAN_OR_REQUIREMENTS: The applicable task from docs/rocketclaw/plans/deployment-plan.md
  BASE_REVISION: The selected starting jj change or commit ID
  HEAD_REVISION: The selected ending jj change or commit ID

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
