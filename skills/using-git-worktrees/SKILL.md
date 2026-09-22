---
name: using-git-worktrees
description: Use when starting feature work that needs isolation from current workspace or before executing implementation plans - ensures an isolated workspace exists via native tools or jj workspace fallback
---

# Using Jujutsu Workspaces

## Overview

Ensure work happens in an isolated workspace. Prefer your platform's native workspace/isolation tools. Fall back to manual `jj workspace add` only when no native tool is available.

**Core principle:** Detect existing isolation first. Then use native tools. Then fall back to jj workspaces. Never fight the harness.

**Announce at start:** "I'm using the using-git-worktrees skill to set up an isolated workspace."

## Step 0: Detect Existing Isolation

**Before creating anything, check if you are already in an isolated workspace.**

```bash
CURRENT_ROOT=$(jj workspace root 2>/dev/null) || CURRENT_ROOT=""
DEFAULT_ROOT=$(jj workspace root --name default 2>/dev/null) || DEFAULT_ROOT=""
jj workspace list
BOOKMARKS=$(jj log -r @ -T 'bookmarks' --no-graph 2>/dev/null)
```

**How to read the result:**

- `jj workspace list` shows every workspace name and path for this repo.
- Compare `CURRENT_ROOT` to the default workspace path. If they differ, you are already in a non-default (isolated) workspace.
- The default workspace is usually named `default`. Any other name (or a path that is not the primary checkout) means isolation is already in place.

**If already in a non-default workspace:** Skip to Step 2 (Project Setup). Do NOT create another workspace.

Report with bookmark state:

- With bookmarks on `@`: "Already in isolated workspace at `<path>` on bookmark(s) `<names>`."
- No bookmarks on `@`: "Already in isolated workspace at `<path>` (no bookmark on `@`, externally managed). Bookmark creation may be needed at finish time."

**If in the default workspace only:** You are in the primary checkout.

Has the user already indicated their workspace preference in your instructions? If not, ask for consent before creating a workspace:

> "Would you like me to set up an isolated workspace? It protects your current working copy from changes."

Honor any existing declared preference without asking. If the user declines consent, work in place and skip to Step 2.

## Step 1: Create Isolated Workspace

**You have two mechanisms. Try them in this order.**

### 1a. Native Workspace Tools (preferred)

The user has asked for an isolated workspace (Step 0 consent). Do you already have a way to create a workspace? It might be a tool with a name like `EnterWorktree`, `WorktreeCreate`, `session_move`, a `/worktree` or `/workspace` command, or a `--worktree` / `--workspace` flag. If you do, use it and skip to Step 2.

Native tools handle directory placement, bookmark creation, and cleanup automatically. Using `jj workspace add` when you have a native tool creates phantom state your harness can't see or manage.

Only proceed to Step 1b if you have no native workspace tool available.

### 1b. Jujutsu Workspace Fallback

**Only use this if Step 1a does not apply** — you have no native workspace tool available. Create a workspace manually with jj.

#### Directory Selection

Follow this priority order. Explicit user preference always beats observed filesystem state.

1. **Check your instructions for a declared workspace directory preference.** If the user has already specified one, use it without asking.

2. **Check for an existing project-local workspace directory:**
   ```bash
   ls -d .worktrees 2>/dev/null     # Preferred (hidden); keep name for compatibility
   ls -d worktrees 2>/dev/null      # Alternative
   ls -d .workspaces 2>/dev/null    # jj-oriented alternative
   ```
   If found, use it. Priority when several exist: `.worktrees` > `.workspaces` > `worktrees`.

3. **If there is no other guidance available**, default to `.worktrees/` at the project root (keeps existing project conventions).

#### Safety Verification (project-local directories only)

**MUST verify the directory is ignored before creating a workspace.** Jujutsu respects `.gitignore`.

```bash
# jj respects .gitignore — confirm the path (or a parent pattern) is listed
grep -E '^\s*(\.worktrees|worktrees|\.workspaces)' .gitignore 2>/dev/null
```

**If NOT ignored:** Add the directory to `.gitignore`, then record the change with jj:

```bash
# After editing .gitignore
# Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards.
# Repository-local commit-message syntax as established by project instructions and `git log` ALWAYS wins when it differs from the Go guidance.
jj commit -m "<message composed from the standards above>"
# Or, if you only need to set the description on the current change:
# jj describe -m "<message composed from the standards above>"
```

**Why critical:** Prevents accidentally tracking workspace contents in the repository.

#### Create the Workspace

```bash
# Determine path based on chosen location and a short name for the work
LOCATION=".worktrees"          # or whatever Step 1b directory selection chose
NAME="$BOOKMARK_NAME"          # feature/work name — also used as workspace name when useful
path="$LOCATION/$NAME"

# Create isolated workspace (new working-copy commit; shares repo history)
jj workspace add "$path" --name "$NAME"
# Optionally pin parents or start from a revision:
# jj workspace add "$path" --name "$NAME" -r main

cd "$path"

# Create or set a bookmark for this work when needed
jj bookmark set "$BOOKMARK_NAME" -r @
```

**Cleanup later (when done with the isolated workspace):**

```bash
jj workspace forget "$NAME"    # stop tracking; does not delete files
rm -rf "$path"                 # remove the directory on disk
```

**Sandbox fallback:** If `jj workspace add` fails with a permission error (sandbox denial), tell the user the sandbox blocked workspace creation and you're working in the current directory instead. Then run setup and baseline tests in place.

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
| Already in non-default jj workspace | Skip creation (Step 0) |
| `jj workspace list` shows only default | Primary checkout — consider isolation |
| Native workspace tool available | Use it (Step 1a) |
| No native tool | `jj workspace add` fallback (Step 1b) |
| `.worktrees/` exists | Use it (verify ignored) |
| `.workspaces/` exists | Use it (verify ignored) |
| `worktrees/` exists | Use it (verify ignored) |
| Several exist | Prefer `.worktrees/` then `.workspaces/` then `worktrees/` |
| Neither exists | Check instruction file, then default `.worktrees/` |
| Directory not ignored | Add to `.gitignore` + `jj commit`/`jj describe` |
| Permission error on create | Sandbox fallback, work in place |
| Tests fail during baseline | Report failures + ask |
| No package.json/Cargo.toml | Skip dependency install |
| Done with isolated workspace | `jj workspace forget` + `rm -rf` path |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "I'm obviously not in a workspace — no need to check" | Run Step 0. Harness-created isolation fools eyeballing; `jj workspace list` and comparing `jj workspace root` settle it. |
| "`jj workspace add` is quicker than hunting for a native tool" | A native tool owns placement, bookmarks, and cleanup. Bypassing it is the #1 mistake — it creates phantom state your harness can't see or manage. |
| "The workspace directory is surely ignored already" | Confirm via `.gitignore` (jj respects it). An unignored workspace directory can track the whole tree into the repo. |
| "Any directory name works" | Explicit instructions beat an existing project-local directory, which beats the `.worktrees/` default. |
| "The workspace is fresh — baseline tests can wait" | A dirty baseline makes every later failure ambiguous. Run the tests now; proceeding past failures is your human partner's call. |
