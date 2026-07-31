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
- Before advancing the target bookmark to land the work

**Optional but valuable:**
- When stuck (fresh perspective)
- Before refactoring (baseline check)
- After fixing complex bug

## How to Request

**1. Inspect local guidance and choose Jujutsu revisions:**
```bash
jj --ignore-working-copy file list
jj --ignore-working-copy file show -r @ path/to/applicable-instructions
jj --ignore-working-copy log -r '::@ | bookmarks()' -n 20
jj status  # snapshot the working copy before resolving review endpoints
BASE_REVISION=$(jj --ignore-working-copy log --no-graph -r 'first_parent(@)' -T 'commit_id ++ "\n"')  # or use trunk()
END_REVISION=$(jj --ignore-working-copy log --no-graph -r '@' -T 'commit_id ++ "\n"')
```

At runtime, use `jj` to locate and read every applicable local instruction file and inspect the change graph, bookmarks, and recent change descriptions before choosing the review range or composing or editing review messages or change descriptions. Select the revision immediately before the reviewed work as `{BASE_REVISION}` and the revision containing all reviewed work as `{END_REVISION}`; do not assume `@` contains the completed work because `jj commit` creates a new working-copy change. Local conventions take precedence; apply the Go guidance only where it is compatible with them. Do not impose a fixed syntax, template, prefix, or example.

Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards.

**2. Dispatch code reviewer subagent:**

Dispatch a `general-purpose` subagent, filling the template at [code-reviewer.md](code-reviewer.md)

**Placeholders:**
- `{DESCRIPTION}` - Brief summary of what you built
- `{PLAN_OR_REQUIREMENTS}` - What it should do
- `{BASE_REVISION}` - Starting revision or revset expression
- `{END_REVISION}` - Ending revision or revset expression

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
BASE_REVISION=$(jj --ignore-working-copy log --no-graph -r 'first_parent(@)' -T 'commit_id ++ "\n"')
END_REVISION=$(jj --ignore-working-copy log --no-graph -r '@' -T 'commit_id ++ "\n"')

[Dispatch code reviewer subagent]
  DESCRIPTION: Added verifyIndex() and repairIndex() with 4 issue types
  PLAN_OR_REQUIREMENTS: Task 2 from docs/rocketclaw/plans/deployment-plan.md
  BASE_REVISION: [resolved starting commit ID]
  END_REVISION: [resolved ending commit ID]

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
