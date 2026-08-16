---
name: requesting-code-review
description: Use when completing tasks, implementing major features, or before landing changes to verify work meets requirements
---

# Requesting Code Review

Dispatch a code reviewer subagent to catch issues before they cascade. The reviewer gets precisely crafted context for evaluation — never your session's history.

**Core principle:** Review early, review often.

## When to Request Review

**Mandatory:**
- After each task in subagent-driven development
- After completing major feature
- Before landing on `trunk()`

**Optional but valuable:**
- When stuck (fresh perspective)
- Before refactoring (baseline check)
- After fixing complex bug

## How to Request

**1. Choose Jujutsu review revsets:**
```bash
BASE_REVSET='[BASE_REVSET]'
HEAD_REVSET='[COMPLETED_TIP_REVSET]'
```

Each revset must resolve to exactly one revision. The reviewer compares the tree at `BASE_REVSET` with the tree at `HEAD_REVSET`. After `jj commit`, the completed tip is normally `@-` because `@` is the new empty working-copy child; when the current working-copy revision contains the completed work, the tip is `@`. Confirm with `jj log` rather than assuming.

**2. Dispatch code reviewer subagent:**

Dispatch a `general-purpose` subagent, filling the template at [code-reviewer.md](code-reviewer.md)

**Placeholders:**
- `{DESCRIPTION}` - Brief summary of what you built
- `{PLAN_OR_REQUIREMENTS}` - What it should do
- `{BASE_REVSET}` - Revset resolving to the starting revision
- `{HEAD_REVSET}` - Revset resolving to the ending revision

When composing a change description or editing, validating, or recommending a commit message, runtime repository instructions and the repository-prescribed `git log` syntax take precedence. Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards. Where compatible, keep the description clear and concise and preserve useful rationale rather than merely restating the diff. Do not impose a fixed message, prefix, type, scope, subject, body, or template.

**3. Act on feedback:**
- Fix Critical issues immediately
- Fix Important issues before proceeding
- Note Minor issues for later
- Push back if reviewer is wrong (with reasoning)

## Example

```
[Just completed Task 2: Add verification function]

You: Let me request code review before proceeding.

BASE_REVSET='[TASK_1_REVSET]'
HEAD_REVSET='@'

[Dispatch code reviewer subagent]
  DESCRIPTION: [SUMMARY_OF_IMPLEMENTED_WORK]
  PLAN_OR_REQUIREMENTS: Task 2 from docs/plans/deployment-plan.md
  BASE_REVSET: [TASK_1_REVSET]
  HEAD_REVSET: @

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
