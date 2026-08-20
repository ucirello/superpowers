---
name: using-git-worktrees
description: Use when starting feature work that needs isolation from the current workspace or before executing implementation plans - ensures an isolated workspace exists via native tools or Jujutsu workspaces
---

# Using Isolated Jujutsu Workspaces

## Overview

Ensure work happens in an isolated workspace. Prefer the platform's native worktree tools when they manage isolation for the harness. Otherwise, create a Jujutsu workspace rather than a legacy worktree.

**Core principle:** Detect existing isolation first. Then use native tools. Then fall back to `jj workspace add`. Never create parallel worktree state behind the harness.

**Announce at start:** "I'm setting up an isolated workspace before starting work."

## Step 0: Detect Existing Isolation

**Before creating anything, check whether the current JJ workspace is already dedicated to this work.**

```bash
WORKSPACE_ROOT=$(jj workspace root 2>/dev/null)
jj workspace list
jj status
jj bookmark list -r @
```

`jj workspace root` prints the current workspace root. `jj workspace list` shows every workspace and marks the current one in its normal output. `jj status` reports the working-copy change (`@`), its parents, changed files, conflicts, and conflicted bookmarks.

Jujutsu has no active or checked-out bookmark. `jj bookmark list -r @` only reports bookmarks currently pointing at `@`; an empty result is normal and does not mean the workspace is detached.

**If the harness or the user's instructions identify the current workspace as isolated for this task:** Skip to Step 2 (Project Setup). Do NOT create another workspace.

Report its actual state:
- "Already in isolated workspace at `<path>` on change `<change-id>`."
- If bookmarks point at `@`, append: "Bookmarks at this change: `<names>`."
- If none point at `@`, append: "No bookmark currently points at this change."

**If `jj workspace root` fails:** Stop and report that the current directory is not a JJ workspace. Do not silently substitute another version-control system's worktree commands.

If the current workspace is not already dedicated to this task, has the user already indicated their isolation preference in the instructions? If not, ask for consent before creating a workspace:

> "Would you like me to set up an isolated workspace? It protects the current working-copy change from task changes."

Honor any existing declared preference without asking. If the user declines consent, work in place and skip to Step 2.

## Step 1: Create Isolated Workspace

**You have two mechanisms. Try them in this order.**

### 1a. Native Worktree Tools (preferred)

The user has asked for an isolated workspace (Step 0 consent). Do you already have a way to create a worktree? It might be a tool with a name like `EnterWorktree`, `WorktreeCreate`, a `/worktree` command, or a `--worktree` flag. If you do, use it and skip to Step 2.

Native tools handle directory placement, branch creation, and cleanup automatically. Creating a manual worktree when you have a native tool creates phantom state your harness can't see or manage.

Only proceed to Step 1b if you have no native worktree tool available.

### 1b. Jujutsu Workspace Fallback

**Only use this if Step 1a does not apply** - you have no native worktree tool available. Create a workspace with Jujutsu.

#### Directory Selection

Use a project-local `.tmp` directory under the current JJ workspace root. If root discovery is unavailable only while calculating a local path, fall back to the current directory; Step 0 still requires a working JJ repository before workspace creation.

```bash
workspace_root=$(jj workspace root 2>/dev/null || pwd -P)
location="$workspace_root/.tmp"
path="$location/$WORKSPACE_NAME"
```

An explicit user destination takes precedence. Do not reuse path mappings or global worktree directories from another harness.

#### Safety Verification

Jujutsu automatically tracks new files unless ignore rules exclude them. Before creating a nested workspace, verify that the root `.gitignore` excludes `.tmp/`. If it does not, add `.tmp/` before proceeding so the containing workspace cannot snapshot the nested workspace contents.

If adding the ignore rule changes the current working-copy change, inspect the exact change with `jj diff` and `jj status`, then describe it before starting another change. Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards. Repository-local instructions and existing history take precedence; inspect the local convention dynamically and use only compatible Go guidance where the repository does not decide wording or structure. Use `jj describe -m '<message composed from the standards above>'`, then `jj new` before creating the task workspace.

**Why critical:** Ignored files are not automatically tracked by JJ; without the rule, the containing workspace can snapshot the nested workspace files.

#### Create the Workspace

```bash
mkdir -p "$location"
jj workspace add "$path" --name "$WORKSPACE_NAME" -r @-
cd "$path"
jj status
jj workspace root
jj bookmark list -r @
```

`-r @-` creates the new working-copy change on the parent of the current working-copy change, isolating it from changes in the original `@`. The workspace starts without an active bookmark because JJ has no active-bookmark concept. Do not create or move a bookmark merely to imitate branch creation; use `jj bookmark set <name> -r @` only when the user or repository workflow requires a named publishing pointer.

**Sandbox fallback:** If `jj workspace add` fails with a permission error (sandbox denial), tell the user the sandbox blocked workspace creation and work in the current directory instead. Then run setup and baseline tests in place.

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
Working-copy change: <change-id>
Bookmarks at @: <names-or-none>
Tests passing (<N> tests, 0 failures)
Ready to implement <feature-name>
```

## Quick Reference

| Situation | Action |
|-----------|--------|
| Already in a task-dedicated workspace | Skip creation (Step 0) |
| Native worktree tool available | Use it (Step 1a) |
| No native tool | Use `jj workspace add` (Step 1b) |
| No explicit destination | Use `$(jj workspace root)/.tmp/<workspace-name>` |
| `jj workspace root` fails | Report that JJ is unavailable; do not use another version-control fallback |
| `.tmp/` is not ignored | Add it to root `.gitignore`, inspect, describe, then start a new change |
| Permission error on create | Sandbox fallback, work in place |
| Tests fail during baseline | Report failures + ask |
| No package.json/Cargo.toml | Skip dependency install |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "I'm obviously isolated - no need to check" | Run Step 0. Harness-created isolation is easy to miss; `jj workspace root`, `jj workspace list`, and `jj status` expose the actual state. |
| "A manual worktree is quicker than learning JJ workspace syntax" | `jj workspace add <destination> -r @-` creates the isolated working-copy change without introducing parallel worktree state. |
| "The workspace directory is surely ignored already" | Verify `.tmp/` in the root ignore rules. JJ automatically tracks new, non-ignored files. |
| "I need a branch name for the new workspace" | JJ workspaces have working-copy changes, not active branches. Create or move a bookmark only when the publishing workflow requires one. |
| "Any directory name works" | Explicit user instructions win; otherwise keep temporary workspaces under the current workspace root's `.tmp/`. |
| "The workspace is fresh - baseline tests can wait" | A dirty baseline makes every later failure ambiguous. Run the tests now; proceeding past failures is your human partner's call. |
