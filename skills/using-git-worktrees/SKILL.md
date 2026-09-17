---
name: using-git-worktrees
description: Use when starting feature work that needs isolation from current workspace or before executing implementation plans - ensures an isolated workspace exists via native tools or jj workspace fallback
---

# Using Jujutsu Workspaces

## Overview

Ensure work happens in an isolated workspace. Prefer your platform's native workspace tools. Fall back to manual `jj workspace add` only when no native tool is available.

**Core principle:** Detect existing isolation first. Then use native tools. Then fall back to jj. Never fight the harness.

**Announce at start:** "I'm using the using-git-worktrees skill to set up an isolated workspace."

## Step 0: Detect Existing Isolation

**Before creating anything, check if you are already in an isolated workspace.**

```bash
CURRENT_ROOT=$(jj workspace root 2>/dev/null)
# List all workspaces and their roots (name + path per line from jj workspace list)
jj workspace list
# Bookmarks pointing at the working-copy commit
jj bookmark list -r @
```

**Multi-workspace detection:** Compare the current workspace root to other workspace roots from `jj workspace list`. If this checkout is not the default/main workspace (its root differs from the primary workspace root, or `jj workspace list` shows multiple workspaces and you are inside a non-default one), you are already in a linked workspace.

**If already in a non-default workspace:** You are already in a linked workspace. Skip to Step 2 (Project Setup). Do NOT create another workspace.

Report with bookmark state:
- Local bookmark on `@`: "Already in isolated workspace at `<path>` on bookmark `<name>`."
- No local bookmark on `@` (externally managed workspace): "Already in isolated workspace at `<path>` (working copy without a local bookmark on `@`, externally managed). Bookmark creation needed at finish time."

**If only the default workspace exists (or you are in the primary workspace root):** You are in a normal repo checkout.

Has the user already indicated their workspace preference in your instructions? If not, ask for consent before creating a workspace:

> "Would you like me to set up an isolated workspace? It protects your current working copy from changes."

Honor any existing declared preference without asking. If the user declines consent, work in place and skip to Step 2.

## Step 1: Create Isolated Workspace

**You have two mechanisms. Try them in this order.**

### 1a. Native Workspace Tools (preferred)

The user has asked for an isolated workspace (Step 0 consent). Do you already have a way to create a workspace? It might be a tool with a name like `EnterWorktree`, `WorktreeCreate`, a `/worktree` command, or a `--worktree` flag. If you do, use it and skip to Step 2.

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
   ls -d worktrees 2>/dev/null      # Alternative
   ```
   If found, use it. If both exist, `.worktrees` wins.

3. **If there is no other guidance available**, default to `.worktrees/` at the project root.

#### Safety Verification (project-local directories only)

**MUST verify directory is ignored before creating workspace:**

jj honors `.gitignore` (and related ignore files). There is no `jj check-ignore`; verify manually:

```bash
# Directory is ignored if a matching ignore rule exists
grep -E '^\.worktrees/?$|^worktrees/?$|^\.worktrees/|^/\.worktrees' .gitignore 2>/dev/null
# Also check ignore files under ignored path patterns if present
```

Or confirm the path would not be auto-tracked: ignored paths are never auto-tracked by jj. If the directory name is not covered by `.gitignore`, treat it as not ignored.

**If NOT ignored:** Add to `.gitignore`, then record the change. Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards. (Inspect history with `jj log` as well; repo-local syntax wins at runtime.) Apply with:

```bash
jj commit -m "<message composed from the standards above>"
```

or `jj describe -m "<message composed from the standards above>"` then `jj new` when that better matches the local workflow. No fixed Conventional Commit prefixes (`feat:`, `fix:`). No staging step — jj auto-snapshots; just edit files.

**Why critical:** Prevents accidentally committing workspace contents to the repository.

#### Create the Workspace

```bash
# Determine path based on chosen location
path="$LOCATION/$BOOKMARK_NAME"

jj workspace add "$path" --name "$BOOKMARK_NAME"
# Optionally pin a revision: jj workspace add "$path" -r <rev>
cd "$path"

# Create or set a bookmark for this work when you want a named tip
jj bookmark create "$BOOKMARK_NAME" -r @
```

**Sandbox fallback:** If `jj workspace add` fails with a permission error (sandbox denial), tell the user the sandbox blocked workspace creation and you're working in the current directory instead. Then run setup and baseline tests in place.

**Cleanup later (when done):** `jj workspace forget <name>` and remove the directory from disk.

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
| Already in non-default workspace | Skip creation (Step 0) |
| Only default/primary workspace | Treat as normal checkout (Step 0) |
| Native workspace tool available | Use it (Step 1a) |
| No native tool | jj workspace fallback (Step 1b) |
| `.worktrees/` exists | Use it (verify ignored) |
| `worktrees/` exists | Use it (verify ignored) |
| Both exist | Use `.worktrees/` |
| Neither exists | Check instruction file, then default `.worktrees/` |
| Directory not ignored | Add to .gitignore + jj commit/describe |
| Permission error on create | Sandbox fallback, work in place |
| Tests fail during baseline | Report failures + ask |
| No package.json/Cargo.toml | Skip dependency install |
| Forget a workspace | `jj workspace forget` + remove directory |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "I'm obviously not in a workspace — no need to check" | Run Step 0. Harness-created isolation fools eyeballing; `jj workspace list` and comparing workspace roots settle it. |
| "`jj workspace add` is quicker than hunting for a native tool" | A native tool (e.g. `EnterWorktree`) owns placement, bookmarks, and cleanup. Bypassing it is the #1 mistake — it creates phantom state your harness can't see or manage. |
| "The workspace directory is surely ignored already" | Check `.gitignore` (and related ignore files). An unignored workspace directory commits the whole tree into the repo. |
| "Any directory name works" | Explicit instructions beat an existing project-local directory, which beats the `.worktrees/` default. |
| "The workspace is fresh — baseline tests can wait" | A dirty baseline makes every later failure ambiguous. Run the tests now; proceeding past failures is your human partner's call. |
