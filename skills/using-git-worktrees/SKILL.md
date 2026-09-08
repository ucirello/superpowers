---
name: using-git-worktrees
description: Use when starting feature work that needs isolation from current workspace or before executing implementation plans - ensures an isolated workspace exists via native tools or jj workspace fallback
---

# Using Git Worktrees

## Overview

Ensure work happens in an isolated workspace. Prefer your platform's native worktree tools. Fall back to manual jj workspaces only when no native tool is available.

**Core principle:** Detect existing isolation first. Then use native tools. Then fall back to jj. Never fight the harness.

**Announce at start:** "I'm using the using-git-worktrees skill to set up an isolated workspace."

## Step 0: Detect Existing Isolation

**Before creating anything, check if you are already in an isolated workspace.**

```bash
WORKSPACE_PATH=$(jj workspace root)
DEFAULT_PATH=$(jj workspace root -w default 2>/dev/null || echo "$WORKSPACE_PATH")
BOOKMARKS_AT_WC=$(jj log -r @ --no-graph -T 'bookmarks.map(|b| b.name()).join(" ")' 2>/dev/null | xargs)
```

**If `WORKSPACE_PATH != DEFAULT_PATH`:** You are already in a secondary jj workspace. Skip to Step 2 (Project Setup). Do NOT create another workspace.

Report with bookmark state:
- Named bookmark at `@`: "Already in isolated workspace at `<path>` on bookmark `<name>`."
- No bookmark at `@`: "Already in isolated workspace at `<path>` (no bookmark at working copy, externally managed). Bookmark creation needed at finish time."

**If `WORKSPACE_PATH == DEFAULT_PATH`:** You are in the default workspace.

Has the user already indicated their worktree preference in your instructions? If not, ask for consent before creating a workspace:

> "Would you like me to set up an isolated workspace? It protects your current working copy from changes."

Honor any existing declared preference without asking. If the user declines consent, work in place and skip to Step 2.

## Step 1: Create Isolated Workspace

**You have two mechanisms. Try them in this order.**

### 1a. Native Worktree Tools (preferred)

The user has asked for an isolated workspace (Step 0 consent). Do you already have a way to create a worktree? It might be a tool with a name like `EnterWorktree`, `WorktreeCreate`, a `/worktree` command, or a `--worktree` flag. If you do, use it and skip to Step 2.

Native tools handle directory placement, branch/bookmark creation, and cleanup automatically. Using `jj workspace add` when you have a native tool creates phantom state your harness can't see or manage.

Only proceed to Step 1b if you have no native worktree tool available.

### 1b. JJ Workspace Fallback

**Only use this if Step 1a does not apply** — you have no native worktree tool available. Create a workspace manually using jj.

#### Directory Selection

Follow this priority order. Explicit user preference always beats observed filesystem state.

1. **Check your instructions for a declared worktree directory preference.** If the user has already specified one, use it without asking.

2. **Check for an existing project-local worktree directory:**
   ```bash
   ls -d .worktrees 2>/dev/null     # Preferred (hidden)
   ls -d worktrees 2>/dev/null      # Alternative
   ```
   If found, use it. If both exist, `.worktrees` wins.

3. **If there is no other guidance available**, default to `.worktrees/` at the project root.

#### Safety Verification (project-local directories only)

**MUST verify directory is ignored before creating workspace:**

```bash
# Verify the chosen directory is listed in ignore rules
grep -E '^\.worktrees/?$|^worktrees/?$' .gitignore 2>/dev/null \
  || grep -E '^\.worktrees/?$|^worktrees/?$' .ignore 2>/dev/null
```

**If NOT ignored:** Add to .gitignore (and .ignore if the project uses it), then create a JJ change for that ignore update. Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards. Repository-local syntax from project instructions and log ALWAYS wins over Go guidance when they differ. Use `jj commit -m "<message composed from the standards above>"`. Then proceed.

**Why critical:** Prevents accidentally committing workspace contents to repository.

#### Create the Workspace

```bash
# Determine path based on chosen location
path="$LOCATION/$BRANCH_NAME"

jj workspace add "$path" --name "$BRANCH_NAME"
# Create a bookmark for the feature work at the new workspace's working copy
jj -R "$path" bookmark create "$BRANCH_NAME" -r @
cd "$path"
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
| Already in secondary jj workspace | Skip creation (Step 0) |
| Native worktree tool available | Use it (Step 1a) |
| No native tool | JJ workspace fallback (Step 1b) |
| `.worktrees/` exists | Use it (verify ignored) |
| `worktrees/` exists | Use it (verify ignored) |
| Both exist | Use `.worktrees/` |
| Neither exists | Check instruction file, then default `.worktrees/` |
| Directory not ignored | Add to .gitignore + jj commit |
| Permission error on create | Sandbox fallback, work in place |
| Tests fail during baseline | Report failures + ask |
| No package.json/Cargo.toml | Skip dependency install |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "I'm obviously not in a worktree — no need to check" | Run Step 0. Harness-created isolation fools eyeballing; the detection commands settle it. |
| "`jj workspace add` is quicker than hunting for a native tool" | A native tool (e.g. `EnterWorktree`) owns placement, branching, and cleanup. Bypassing it is the #1 mistake — it creates phantom state your harness can't see or manage. |
| "The worktree directory is surely ignored already" | Verify ignore rules. An unignored workspace directory commits the whole tree into the repo. |
| "Any directory name works" | Explicit instructions beat an existing project-local directory, which beats the `.worktrees/` default. |
| "The workspace is fresh — baseline tests can wait" | A dirty baseline makes every later failure ambiguous. Run the tests now; proceeding past failures is your human partner's call. |
