---
name: executing-plans
description: Use when you have a written implementation plan to execute in a separate session with review checkpoints
---

# Executing Plans

## Overview

Load plan, review critically, execute all tasks, report when complete.

**Announce at start:** "I'm using the executing-plans skill to implement this plan."

**Note:** Tell your human partner that this workflow works much better with access to subagents (Claude Code, Codex CLI, Codex App, Copilot CLI, and Gemini CLI all qualify). If subagents are available, use superpowers:subagent-driven-development instead of this skill.

## The Process

### Step 1: Load and Review Plan
1. Inspect repository instructions, including instructions scoped to files you will change; the most local syntax and conventions win
2. Ensure an isolated workspace: use superpowers:using-git-worktrees for the isolation workflow, implemented with `jj workspace add`, or verify the current workspace with `jj workspace list`
3. Read plan file
4. Review critically - identify any questions or concerns about the plan
5. If concerns: Raise them with your human partner before starting
6. If no concerns: Create todos for the plan items and proceed

### Execution Environment

- Store persistent workflow artifacts under `$(jj workspace root)/.rocketclaw/`; keep project artifacts at paths required by the plan or repository instructions
- Put temporary files under `$(jj workspace root)/.tmp/`; if no workspace root is available, use a local `.tmp/` directory
- Before composing a change description with `jj describe`, inspect repository instructions and history; local syntax wins
- Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards.
- Where compatible with repository precedent, keep the first line concise and use a plain-text body to explain what changed and why when useful; never impose a fixed type, scope, prefix, subject, body, or template

### Step 2: Execute Tasks

For each task:
1. Mark as in_progress
2. Follow each step exactly (plan has bite-sized steps)
3. Run verifications as specified
4. Mark as completed

### Step 3: Complete Development

After all tasks complete and verified:
- Announce: "I'm using the finishing-a-development-branch skill to complete this work."
- **REQUIRED SUB-SKILL:** Use superpowers:finishing-a-development-branch
- Follow that skill to verify tests, present options, execute choice

## When to Stop and Ask for Help

**STOP executing immediately when:**
- Hit a blocker (missing dependency, test fails, instruction unclear)
- Plan has critical gaps preventing starting
- You don't understand an instruction
- Verification fails repeatedly

**Ask for clarification rather than guessing.**

## When to Revisit Earlier Steps

**Return to Review (Step 1) when:**
- Partner updates the plan based on your feedback
- Fundamental approach needs rethinking

**Don't force through blockers** - stop and ask.

## Remember
- Review plan critically first
- Follow plan steps exactly
- Don't skip verifications
- Reference skills when plan says to
- Stop when blocked, don't guess
- Never start implementation directly on the repository's trunk bookmark without explicit user consent
