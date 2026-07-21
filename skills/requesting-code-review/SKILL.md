---
name: requesting-code-review
description: Use when completing tasks, implementing major features, or before integration to verify work meets requirements
---

# Requesting Code Review

Dispatch a code reviewer subagent to catch issues before they cascade. The reviewer gets precisely crafted context for evaluation — never your session's history. This keeps the reviewer focused on the work product, not your thought process, and preserves your own context for continued work.

**Core principle:** Review early, review often.

## When to Request Review

**Mandatory:**
- After each task in subagent-driven development
- After completing major feature
- Before integrating changes into the target bookmark

**Optional but valuable:**
- When stuck (fresh perspective)
- Before refactoring (baseline check)
- After fixing complex bug

## How to Request

**1. Choose the Jujutsu revision range:**
```bash
jj status  # Snapshot the current working copy before resolving endpoints.
BASE_REV=$(jj log --no-graph -r '@-' -T 'commit_id ++ "\n"')  # or resolve main@origin
END_REV=$(jj log --no-graph -r '@' -T 'commit_id ++ "\n"')
```

Pass immutable commit IDs to the reviewer so its read-only `--ignore-working-copy` commands inspect the snapshotted endpoints exactly. Local instructions and repository history take precedence.

**2. Dispatch code reviewer subagent:**

Dispatch a `general-purpose` subagent, filling the template at [code-reviewer.md](code-reviewer.md)

**Placeholders:**
- `{DESCRIPTION}` - Brief summary of what you built
- `{PLAN_OR_REQUIREMENTS}` - What it should do
- `{BASE_REV}` - Starting revision
- `{END_REV}` - Ending revision

**3. Act on feedback:**
- Fix Critical issues immediately
- Fix Important issues before proceeding
- Note Minor issues for later
- Push back if reviewer is wrong (with reasoning)

## Example

```
[Just completed Task 2: Add verification function]

You: Let me request code review before proceeding.

BASE_REV=<revision selected from jj log>
END_REV=[Resolved immutable commit ID]

[Dispatch code reviewer subagent]
  DESCRIPTION: [Concise factual summary of the completed work]
  PLAN_OR_REQUIREMENTS: Task 2 from docs/rocketclaw/plans/deployment-plan.md
  BASE_REV: [Revision selected from repository history]
  END_REV: [Resolved immutable commit ID]

[Subagent returns]:
  Strengths: Clean architecture, real tests
  Issues:
    Important: Missing progress indicators
    Minor: Magic number (100) for reporting interval
  Assessment: Ready to proceed

You: [Fix progress indicators]
[Continue to Task 3]
```

## Integration with Workflows

**Subagent-Driven Development:**
- Review after EACH task
- Catch issues before they compound
- Fix before moving to next task

**Executing Plans:**
- Review after each task or at natural checkpoints
- Get feedback, apply, continue

**Ad-Hoc Development:**
- Review before integration
- Review when stuck

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
