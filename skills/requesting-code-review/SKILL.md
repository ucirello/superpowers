---
name: requesting-code-review
description: Use when completing tasks, implementing major features, or before integrating changes to verify work meets requirements
---

# Requesting Code Review

Dispatch a code reviewer subagent to catch issues before they cascade. The reviewer gets precisely crafted context for evaluation — never your session's history.

**Core principle:** Review early, review often.

## When to Request Review

**Mandatory:**
- After each task in subagent-driven development
- After completing major feature
- Before integrating changes into the main bookmark

**Optional but valuable:**
- When stuck (fresh perspective)
- Before refactoring (baseline check)
- After fixing complex bug

## How to Request

**1. Get Jujutsu revision IDs:**

Use the stable base recorded before implementation and resolve the actual
completed tip after implementation. After `jj commit`, the completed tip is
normally `@-`; if work remains in the working-copy change, it is `@`. Confirm
both revisions with `jj log` instead of assuming adjacency.

```bash
BASE_REV=$(jj log -r '<recorded-base>' --no-graph -T 'commit_id ++ "\n"')
END_REV=$(jj log -r '<completed-tip>' --no-graph -T 'commit_id ++ "\n"')
```

**2. Dispatch code reviewer subagent:**

Dispatch a `general-purpose` subagent, filling the template at [code-reviewer.md](code-reviewer.md)

**Placeholders:**
- `{DESCRIPTION}` - Brief summary of what you built
- `{PLAN_OR_REQUIREMENTS}` - What it should do
- `{BASE_REV}` - Starting revision
- `{END_REV}` - Ending revision

When composing, editing, validating, or recommending commit messages, repository instructions and the message syntax visible in `git log` always take precedence. Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards. Where compatible, use a concise, clear subject and a wrapped plain-text body explaining what changed and why when needed. Do not impose fixed messages, prefixes, types, scopes, subjects, bodies, templates, or examples.

**3. Act on feedback:**
- Fix Critical issues immediately
- Fix Important issues before proceeding
- Note Minor issues for later
- Push back if reviewer is wrong (with reasoning)

## Example

```
[Just completed Task 2: Add verification function]

You: Let me request code review before proceeding.

BASE_REV=$(jj log -r @-- --no-graph -T 'commit_id ++ "\n"')
END_REV=$(jj log -r @- --no-graph -T 'commit_id ++ "\n"')

[Dispatch code reviewer subagent]
  DESCRIPTION: Added verifyIndex() and repairIndex() with 4 issue types
  PLAN_OR_REQUIREMENTS: Task 2 from docs/rocketclaw/plans/deployment-plan.md
  BASE_REV: a7981ec
  END_REV: 3df7661

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
