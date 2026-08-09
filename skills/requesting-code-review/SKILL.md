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
- Before integrating into the trunk bookmark

**Optional but valuable:**
- When stuck (fresh perspective)
- Before refactoring (baseline check)
- After fixing complex bug

## How to Request

**1. Get exact Jujutsu commit IDs:** Before implementation begins in a fresh
current change, record its parent. After completing the implementation with
`jj commit`, the completed change is `@-`:
```bash
# Run before implementation changes the fresh @.
BASE_COMMIT_ID=$(jj log --ignore-working-copy -r '@-' --no-graph -T 'commit_id ++ "\n"')
# Run after jj commit.
TIP_COMMIT_ID=$(jj log --ignore-working-copy -r '@-' --no-graph -T 'commit_id ++ "\n"')
```

Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards. Repository-local syntax wins; use compatible Go guidance for clarity and structure without imposing a fixed format.

**2. Dispatch code reviewer subagent:**

Dispatch a `general-purpose` subagent, filling the template at [code-reviewer.md](code-reviewer.md)

**Placeholders:**
- `{DESCRIPTION}` - Brief summary of what you built
- `{PLAN_OR_REQUIREMENTS}` - What it should do
- `{BASE_COMMIT_ID}` - Exact starting revision
- `{TIP_COMMIT_ID}` - Exact completed revision

**3. Act on feedback:**
- Fix Critical issues immediately
- Fix Important issues before proceeding
- Note Minor issues for later
- Push back if reviewer is wrong (with reasoning)

## Example

```
[Just completed Task 2: Add verification function]

You: Let me request code review before proceeding.

BASE_COMMIT_ID=<full commit ID recorded before Task 2>
TIP_COMMIT_ID=$(jj log --ignore-working-copy -r '@-' --no-graph -T 'commit_id ++ "\n"')

[Dispatch code reviewer subagent]
  DESCRIPTION: Added verifyIndex() and repairIndex() with 4 issue types
  PLAN_OR_REQUIREMENTS: Task 2 from docs/rocketclaw/plans/deployment-plan.md
  BASE_COMMIT_ID: <full commit ID recorded before Task 2>
  TIP_COMMIT_ID: <full commit ID for the completed Task 2 change>

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
