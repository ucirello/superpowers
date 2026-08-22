---
name: executing-plans
description: Use when you have a written implementation plan to execute in a separate session with review checkpoints
---

# Executing Plans

## Overview

Load plan, review critically, execute all tasks, report when complete.

**Announce at start:** "I'm using the executing-plans skill to implement this plan."

**Note:** Tell your human partner that this workflow works much better with access to subagents (Claude Code, Codex CLI, Codex App, Copilot CLI, and Gemini CLI all qualify; see the per-platform tool refs in `../using-superpowers/references/`). If subagents are available, use superpowers:subagent-driven-development instead of this skill.

## The Process

### Step 1: Load and Review Plan
1. Read repository-local instructions and follow them before this skill; repository-specific commands, quality checks, and change-description style take precedence
2. Ensure an isolated workspace with superpowers:using-git-worktrees; let that skill choose the harness-native or `jj workspace` mechanism
3. Read plan file
4. Review critically - identify any questions or concerns about the plan
5. If concerns: Raise them with your human partner before starting
6. If no concerns: Create todos for the plan items and proceed

### Step 2: Execute Tasks

For each task:
1. Mark as in_progress
2. Follow each step exactly (plan has bite-sized steps)
3. Interpret version-control steps by intent and use their Jujutsu equivalents, such as `jj status`, `jj diff`, `jj log`, `jj new <base-revision>`, `jj describe -m <description>`, `jj bookmark <subcommand> <arguments>`, and `jj git <subcommand> <arguments>`; use `gh` where the plan requires GitHub operations
4. Before composing any commit or Jujutsu change description, inspect repository-local instructions and the existing log style. Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards.
5. Supply the resulting repository-appropriate text through a placeholder command such as `jj describe -m <description>`; do not reuse fixed example messages or syntax from the plan without validating them against the repository
6. Run verifications as specified, using repository-provided commands first
7. Review the completed task with `jj status` and `jj diff`, then mark it as completed

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
- Never edit the repository's trunk revision directly without explicit user consent; create a mutable change from `<trunk-revision>` with `jj new <trunk-revision>`
