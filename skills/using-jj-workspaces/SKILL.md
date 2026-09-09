---
name: using-jj-workspaces
description: Use when starting feature work that needs isolation from current workspace or before executing implementation plans - ensures an isolated workspace exists via native tools or jj workspace fallback
---

# Using Jujutsu Workspaces

## Overview

Ensure work happens in an isolated workspace. Prefer your platform's native workspace tools. Fall back to manual jj workspaces only when no native tool is available.

**Core principle:** Detect existing isolation first. Then use native tools. Then fall back to jj. Never fight the harness.

**Announce at start:** "I'm using the using-jj-workspaces skill to set up an isolated workspace."

## Step 0: Detect Existing Isolation

**Before creating anything, check if you are already in an isolated workspace.**

```bash
ROOT=$(jj workspace root 2>/dev/null)
CURRENT_NAME=$(jj workspace list 2>/dev/null | awk -v root="$ROOT" -F': ' '$2 == root { print $1; exit }')
BOOKMARKS=$(jj log -r @ -T 'bookmarks' --no-graph 2>/dev/null)
```

`jj workspace list` prints `name: path` lines. The default workspace is typically named `default`. A non-default current workspace name means you are already in a linked workspace.

**If current workspace name is set and is not `default`:** You are already in a linked workspace. Skip to Step 2 (Project Setup). Do NOT create another workspace.

Report with bookmark state:
- Has bookmark(s) on `@`: "Already in isolated workspace at `<path>` (workspace `<name>`) on bookmark `<name>`."
- No bookmark on `@`: "Already in isolated workspace at `<path>` (workspace `<name>`, no bookmark on @ — externally managed or in-progress). Bookmark creation needed at finish time."

**If current workspace is `default` (or only one workspace exists):** You are in the default workspace checkout.

Has the user already indicated their workspace preference in your instructions? If not, ask for consent before creating a workspace:

> "Would you like me to set up an isolated workspace? It protects your current working copy from changes."

Honor any existing declared preference without asking. If the user declines consent, work in place and skip to Step 2.

## Step 1: Create Isolated Workspace

**You have two mechanisms. Try them in this order.**

### 1a. Native Workspace Tools (preferred)

The user has asked for an isolated workspace (Step 0 consent). Do you already have a way to create a workspace? It might be a tool with a name like `EnterWorktree`, `WorktreeCreate`, `session_move`, a `/worktree` command, or a `--worktree` flag. If you do, use it and skip to Step 2.

Native tools handle directory placement, bookmark creation, and cleanup automatically. Using `jj workspace add` when you have a native tool creates phantom state your harness can't see or manage.

Only proceed to Step 1b if you have no native workspace tool available.

### 1b. Jujutsu Workspace Fallback

**Only use this if Step 1a does not apply** — you have no native workspace tool available. Create a workspace manually using jj.

#### Directory Selection

Follow this priority order. Explicit user preference always beats observed filesystem state.

1. **Check your instructions for a declared workspace directory preference.** If the user has already specified one, use it without asking.

2. **Check for an existing project-local workspace directory:**
   ```bash
   ls -d .worktrees 2>/dev/null     # Preferred (hidden)
   ls -d workspaces 2>/dev/null     # Alternative
   ls -d worktrees 2>/dev/null      # Legacy alternative
   ```
   If found, use it. Prefer `.worktrees` when several exist.

3. **If there is no other guidance available**, default to `.worktrees/` at the project root.

#### Safety Verification (project-local directories only)

**MUST verify directory is ignored before creating workspace:**

```bash
# jj respects .gitignore; confirm the directory is ignored
grep -qxF '.worktrees/' .gitignore 2>/dev/null \
  || grep -qxF '.worktrees' .gitignore 2>/dev/null \
  || grep -qxF 'workspaces/' .gitignore 2>/dev/null \
  || grep -qxF 'worktrees/' .gitignore 2>/dev/null
```

**If NOT ignored:** Add the directory to `.gitignore` (ignore file — jj respects it), then record the change with jj before proceeding.

Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `jj log`, compose commit messages adherent to the present standards.

```bash
# After editing .gitignore — compose -m from the Go standard and jj log history
jj describe -m "<composed message>"
jj new
```

**Why critical:** Prevents accidentally tracking workspace contents in the repository.

#### Create the Workspace

```bash
# Determine path based on chosen location
path="$LOCATION/$WORKSPACE_NAME"

jj workspace add "$WORKSPACE_NAME" --destination "$path"
cd "$path"

# Optionally set a bookmark on the new workspace's working copy
jj bookmark set "$BOOKMARK_NAME" -r @
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
| Native workspace tool available | Use it (Step 1a) |
| No native tool | jj workspace fallback (Step 1b) |
| `.worktrees/` exists | Use it (verify ignored) |
| `workspaces/` exists | Use it (verify ignored) |
| Both exist | Use `.worktrees/` |
| Neither exists | Check instruction file, then default `.worktrees/` |
| Directory not ignored | Add to .gitignore + jj describe/new |
| Permission error on create | Sandbox fallback, work in place |
| Tests fail during baseline | Report failures + ask |
| No package.json/Cargo.toml | Skip dependency install |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "I'm obviously not in a workspace — no need to check" | Run Step 0. Harness-created isolation fools eyeballing; `jj workspace list` and `jj workspace root` settle it. |
| "`jj workspace add` is quicker than hunting for a native tool" | A native tool owns placement, bookmarks, and cleanup. Bypassing it is the #1 mistake — it creates phantom state your harness can't see or manage. |
| "The workspace directory is surely ignored already" | Verify ignore rules. An unignored workspace directory tracks the whole tree into the repo. |
| "Any directory name works" | Explicit instructions beat an existing project-local directory, which beats the `.worktrees/` default. |
| "The workspace is fresh — baseline tests can wait" | A dirty baseline makes every later failure ambiguous. Run the tests now; proceeding past failures is your human partner's call. |
