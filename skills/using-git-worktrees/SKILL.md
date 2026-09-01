---
name: using-git-worktrees
description: Use when starting feature work that needs isolation from current workspace or before executing implementation plans - ensures an isolated workspace exists via native tools or jj workspace fallback
---

# Using JJ Workspaces

## Overview

Ensure work happens in an isolated workspace. Prefer your platform's native workspace tools. Fall back to manual jj workspaces only when no native tool is available.

**Core principle:** Detect existing isolation first. Then use native tools. Then fall back to jj. Never fight the harness.

**Announce at start:** "I'm using the using-git-worktrees skill to set up an isolated workspace."

## Step 0: Detect Existing Isolation

**Before creating anything, check if you are already in an isolated workspace.**

```bash
# List workspaces; if current root is not the default workspace, already isolated
jj workspace list
jj workspace root
CURRENT_BOOKMARKS=$(jj log -r @ --template 'local_bookmarks' --no-graph 2>/dev/null)
```

**Multi-workspace detection:** Compare `jj workspace root` to the paths from `jj workspace list`. If the current workspace name is not "default" (or the path differs from the primary/default workspace), you are already in an isolated workspace.

**If already in a named secondary workspace:** You are already isolated. Skip to Step 2 (Project Setup). Do NOT create another workspace.

Report with bookmark state:
- On a bookmark: "Already in isolated workspace at `<path>` on bookmark `<name>`."
- Working-copy commit without a bookmark pointing at it: "Already in isolated workspace at `<path>` (working-copy commit without bookmark, externally managed). Bookmark creation needed at finish time."

**If in the default workspace:** You are in a normal repo checkout.

Has the user already indicated their workspace preference in your instructions? If not, ask for consent before creating a workspace:

> "Would you like me to set up an isolated workspace? It protects your current bookmark from changes."

Honor any existing declared preference without asking. If the user declines consent, work in place and skip to Step 2.

## Step 1: Create Isolated Workspace

**You have two mechanisms. Try them in this order.**

### 1a. Native Workspace Tools (preferred)

The user has asked for an isolated workspace (Step 0 consent). Do you already have a way to create a workspace? It might be a tool with a name like `EnterWorktree`, `WorktreeCreate`, a `/worktree` command, or a `--worktree` flag. If you do, use it and skip to Step 2.

Native tools handle directory placement, bookmark creation, and cleanup automatically. Using `jj workspace add` when you have a native tool creates phantom state your harness can't see or manage.

Only proceed to Step 1b if you have no native workspace tool available.

### 1b. JJ Workspace Fallback

**Only use this if Step 1a does not apply** — you have no native workspace tool available. Create a workspace manually using jj.

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

**MUST verify directory is ignored before creating workspace:**

```bash
# jj respects .gitignore; verify path is listed there (files matching ignore aren't tracked)
grep -qxF '.worktrees' .gitignore 2>/dev/null || grep -qxF '.worktrees/' .gitignore 2>/dev/null \
  || grep -qxF 'worktrees' .gitignore 2>/dev/null || grep -qxF 'worktrees/' .gitignore 2>/dev/null
```

**If NOT ignored:** Add to .gitignore, describe the change with jj, then proceed.

Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards.

```bash
# After editing .gitignore:
jj describe -m "<message composed from the standards above>"
# or
jj commit -m "<message composed from the standards above>"
```

**Why critical:** Prevents accidentally committing workspace contents to repository.

#### Create the Workspace

```bash
# Determine path based on chosen location
path="$LOCATION/$BOOKMARK_NAME"

# Create bookmark and workspace (or add workspace at a base revision)
jj bookmark create "$BOOKMARK_NAME" -r @
jj workspace add "$path" --name "$BOOKMARK_NAME" -r "$BOOKMARK_NAME"
# Or from trunk/main without a pre-created bookmark:
# jj workspace add "$path" --name "$BOOKMARK_NAME" -r "trunk()|main|master"
cd "$path"
```

**Sandbox fallback:** If `jj workspace add` fails with a permission error (sandbox denial), tell the user the sandbox blocked workspace creation and you're working in the current directory instead. Then run setup and baseline tests in place.

**Cleanup note:** To remove a workspace later: `jj workspace forget <name>`, then `rm -rf` the directory.

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
| Already in named secondary workspace | Skip creation (Step 0) |
| Native workspace tool available | Use it (Step 1a) |
| No native tool | JJ workspace fallback (Step 1b) |
| `.worktrees/` exists | Use it (verify ignored) |
| `worktrees/` exists | Use it (verify ignored) |
| Both exist | Use `.worktrees/` |
| Neither exists | Check instruction file, then default `.worktrees/` |
| Directory not ignored | Add to .gitignore + jj describe/commit |
| Permission error on create | Sandbox fallback, work in place |
| Tests fail during baseline | Report failures + ask |
| No package.json/Cargo.toml | Skip dependency install |
| Remove workspace | `jj workspace forget <name>` then `rm -rf` directory |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "I'm obviously not in a workspace — no need to check" | Run Step 0. Harness-created isolation fools eyeballing; `jj workspace list` and `jj workspace root` settle it. |
| "`jj workspace add` is quicker than hunting for a native tool" | A native tool (e.g. `EnterWorktree`) owns placement, bookmarks, and cleanup. Bypassing it is the #1 mistake — it creates phantom state your harness can't see or manage. |
| "The workspace directory is surely ignored already" | Verify `.gitignore` lists it. An unignored workspace directory commits the whole tree into the repo. |
| "Any directory name works" | Explicit instructions beat an existing project-local directory, which beats the `.worktrees/` default. |
| "The workspace is fresh — baseline tests can wait" | A dirty baseline makes every later failure ambiguous. Run the tests now; proceeding past failures is your human partner's call. |
