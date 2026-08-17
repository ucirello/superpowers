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
- Before merging into main

**Optional but valuable:**
- When stuck (fresh perspective)
- Before refactoring (baseline check)
- After fixing complex bug

## How to Request

**1. Get Jujutsu revisions:**
```bash
BASE_REVSET='[BASE_REVSET]'
END_REVSET='[COMPLETED_TIP_REVSET]'
BASE_REVISION=$(jj log -r "exactly(($BASE_REVSET), 1)" --no-graph -T 'commit_id ++ "\n"')
END_REVISION=$(jj log -r "exactly(($END_REVSET), 1)" --no-graph -T 'commit_id ++ "\n"')
```

Confirm both endpoints with `jj log`. After `jj commit`, the completed tip is
normally `@-` because `@` is the new empty child; when completed work remains
in the working-copy revision, the tip is `@`.

**2. Dispatch code reviewer subagent:**

Dispatch a `general-purpose` subagent, filling the template at [code-reviewer.md](code-reviewer.md)

**Placeholders:**
- `{DESCRIPTION}` - Brief summary of what you built
- `{PLAN_OR_REQUIREMENTS}` - What it should do
- `{BASE_REVISION}` - Starting revision
- `{END_REVISION}` - Ending revision

If the review evaluates, edits, validates, or recommends a change description,
runtime repository instructions and the repository-prescribed `git log` syntax
take precedence. Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards. Apply only compatible Go guidance for clarity and useful
rationale; do not impose a fixed message, prefix, type, scope, subject, body,
template, or example.

**3. Act on feedback:**
- Fix Critical issues immediately
- Fix Important issues before proceeding
- Note Minor issues for later
- Push back if reviewer is wrong (with reasoning)

## Example

```
[Just completed Task 2: Add verification function]

You: Let me request code review before proceeding.

BASE_REVISION='[BASE_REVISION]'
END_REVISION='[COMPLETED_TIP_REVISION]'

[Dispatch code reviewer subagent]
  DESCRIPTION: Added verifyIndex() and repairIndex() with 4 issue types
  PLAN_OR_REQUIREMENTS: Task 2 from docs/plans/deployment-plan.md
  BASE_REVISION: a7981ecf0123
  END_REVISION: 3df7661abc45

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
