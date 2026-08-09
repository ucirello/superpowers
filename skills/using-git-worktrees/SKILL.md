---
name: using-git-worktrees
description: Use when starting feature work that needs isolation from the current workspace or before executing implementation plans - ensures an isolated Jujutsu workspace exists
---

# Using Jujutsu Workspaces

## Overview

Ensure work happens in an isolated Jujutsu workspace. Prefer native workspace tools and fall back to `jj workspace add` when no native tool is available.

**Core principle:** Detect existing isolation first. Then use native tools. Then fall back to Jujutsu. Never fight the harness.

**Announce at start:** "I'm using the using-git-worktrees skill to set up an isolated workspace."

## Step 0: Detect Existing Isolation

**Before creating anything, check if you are already in an isolated workspace.**

```bash
CURRENT_ROOT=$(jj workspace root)
jj workspace list
```

`jj workspace list` reports registered workspace names and revisions, not their
filesystem roots. Use the current root together with the harness state or
instructions that placed you there to determine whether it is the isolated
workspace intended for this task.

**If the current root is already the isolated workspace intended for this task:** Skip to Step 2. Do NOT create another workspace.

Otherwise, report the current workspace root and continue.

Has the user already indicated their workspace preference in your instructions? If not, ask for consent before creating a workspace:

> "Would you like me to set up an isolated workspace? It keeps this work separate from your current working copy."

Honor any existing declared preference without asking. If the user declines consent, work in place and skip to Step 2.

## Step 1: Create Isolated Workspace

**You have two mechanisms. Try them in this order.**

### 1a. Native Workspace Tools (preferred)

The user has asked for an isolated workspace (Step 0 consent). Do you already have a native way to create and enter one? It might be a tool with a name like `EnterWorktree`, `WorktreeCreate`, a `/worktree` command, or a `--worktree` flag. If you do, use it and skip to Step 2.

Native tools handle directory placement and cleanup automatically. Using `jj workspace add` when you have a native tool creates state your harness can't see or manage.

Only proceed to Step 1b if you have no native workspace tool available.

### 1b. Jujutsu Workspace Fallback

**Only use this if Step 1a does not apply.** Create the workspace with Jujutsu.

#### Directory Selection

Follow this priority order. Explicit user preference always beats observed filesystem state.

1. **Check your instructions for a declared workspace directory preference.** If the user has already specified one, use it without asking.

2. **Check for an existing project-local workspace directory:**

   ```bash
   ls -d .worktrees 2>/dev/null     # Preferred (hidden)
   ls -d worktrees 2>/dev/null      # Alternative
   ```
   If found, use it. If both exist, `.worktrees` wins.

3. **If there is no other guidance available**, default to `.worktrees/` at the project root.

#### Safety Verification (project-local directories only)

**MUST ensure the directory ignores its own contents before creating a workspace:**

```bash
mkdir -p "$LOCATION"
if [ ! -e "$LOCATION/.gitignore" ]; then printf '*\n' > "$LOCATION/.gitignore"; fi
```

**Why critical:** Prevents accidentally snapshotting nested workspace contents into the containing workspace.

If the `.gitignore` is newly tracked, record only that file in a Jujutsu
change before proceeding. Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards.

#### Create the Workspace

```bash
# Choose a unique, filesystem-safe workspace name for the task
path="$LOCATION/$WORKSPACE_NAME"

jj workspace add --name "$WORKSPACE_NAME" -r @ "$path"
cd "$path"
```

`-r @` creates the new workspace's working-copy commit on the current revision. Do not create a bookmark merely to isolate the work; Jujutsu workspaces have independent working-copy commits.

When the workspace is no longer needed, run `jj workspace forget "$WORKSPACE_NAME"`; Jujutsu leaves on-disk files for separate removal.

**Permission fallback:** If creation fails because the selected location is not writable, retry with `$(jj workspace root)/.tmp`, or `$PWD/.tmp` if the root cannot be determined. If that also fails, report the restriction and work in place only with user approval.

When composing a change description, follow this instruction exactly:

> Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards.

Use the repository's local syntax. Preserve the semantic requirement to explain the change clearly, but do not impose a fixed format.

## Step 2: Project Setup

Auto-detect and run appropriate setup:

```bash
# Node.js
if [ -f package.json ]; then npm install; fi

# Rust
if [ -f Cargo.toml ]; then cargo build; fi

# Python
if [ -f requirements.txt ]; then pip install -r requirements.txt; fi
if [ -f pyproject.toml ]; then poetry install; fi

# Go
if [ -f go.mod ]; then go mod download; fi
```

## Step 3: Verify Clean Baseline

Run tests to ensure workspace starts clean:

```bash
# Use project-appropriate command
npm test / cargo test / pytest / go test ./...
```

**If tests fail:** Report failures, ask whether to proceed or investigate.

**If tests pass:** Report ready.

### Report

```
Workspace ready at <full-path>
Tests passing (<N> tests, 0 failures)
Ready to implement <feature-name>
```

## Quick Reference

| Situation | Action |
|-----------|--------|
| Already in intended isolated workspace | Skip creation (Step 0) |
| Native workspace tool available | Use it (Step 1a) |
| No native tool | Use `jj workspace add` (Step 1b) |
| `.worktrees/` exists | Use it (ensure contents are ignored) |
| `worktrees/` exists | Use it (ensure contents are ignored) |
| Both exist | Use `.worktrees/` |
| Neither exists | Check instruction file, then default `.worktrees/` |
| Directory not ignored | Add a self-ignoring `.gitignore` and record it |
| Permission error on create | Retry locally, then ask before working in place |
| Tests fail during baseline | Report failures + ask |
| No package.json/Cargo.toml | Skip dependency install |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "I'm obviously not in an isolated workspace; no need to check" | Run Step 0. Harness-created isolation can fool eyeballing; `jj workspace list` is authoritative. |
| "`jj workspace add` is quicker than hunting for a native tool" | A native tool (e.g. `EnterWorktree`) owns placement and cleanup. Bypassing it creates state your harness can't see or manage. |
| "The workspace directory is surely ignored already" | Ensure it has a self-ignoring `.gitignore`. An unignored nested workspace can snapshot the whole tree into the containing workspace. |
| "Any directory name works" | Explicit instructions beat an existing project-local directory, which beats the `.worktrees/` default. |
| "The workspace is fresh — baseline tests can wait" | A dirty baseline makes every later failure ambiguous. Run the tests now; proceeding past failures is your human partner's call. |
