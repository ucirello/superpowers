---
name: using-git-worktrees
description: Use when starting feature work that needs isolation from current workspace or before executing implementation plans - ensures an isolated workspace exists via native tools or Jujutsu workspace fallback
---

# Using Jujutsu Workspaces

## Overview

Ensure work happens in an isolated workspace. Prefer your platform's native workspace tools. Fall back to manual jj workspaces only when no native tool is available.

**Core principle:** Detect existing isolation first. Then use native tools. Then fall back to jj. Never fight the harness.

**Announce at start:** "I'm using the using-git-worktrees skill to set up an isolated workspace."

## Step 0: Detect Existing Isolation

**Before creating anything, check if you are already in an isolated workspace.**

```bash
WS_ROOT=$(jj workspace root 2>/dev/null)
# List workspaces — default is typically named "default"; secondary workspaces have other names
jj workspace list
# Bookmarks pointing at the working-copy commit (may be empty)
BOOKMARKS=$(jj log -r @ -T 'bookmarks' --no-graph 2>/dev/null)
# Or: jj bookmark list -r @
```

**Already isolated if any of these hold:**

- Current workspace name is not `default` (from `jj workspace list`, match the row whose path equals `$WS_ROOT`)
- `$WS_ROOT` (or `$PWD`) is under `.worktrees/` or `worktrees/`

**Nested-checkout guard:** A path can look special for reasons other than a jj workspace (for example a nested checkout inside `node_modules` or a vendor tree). Before concluding "already isolated," confirm `$WS_ROOT` is the project you intend to work in — not a nested throwaway repo.

**If already in a non-default jj workspace or under `.worktrees/`/`worktrees/`:** You are already in an isolated workspace. Skip to Step 2 (Project Setup). Do NOT create another workspace.

Report with bookmark state:
- Bookmark(s) on `@`: "Already in isolated workspace at `<path>` on bookmark `<name>`."
- No bookmark on `@` (anonymous working-copy change): "Already in isolated workspace at `<path>` (no bookmark on working copy, externally managed). Bookmark creation needed at finish time."

**If in the default workspace (and not under a project-local worktrees directory):** You are in a normal repo checkout.

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

```bash
# Prefer verifying the directory is listed in .gitignore (jj respects gitignore)
grep -E '^\s*\.worktrees/?\s*$|^\s*worktrees/?\s*$' .gitignore 2>/dev/null
```

**If NOT ignored:** Add to .gitignore, commit the change, then proceed.

Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards. (You may also inspect style via `jj log`.) Do not use a fixed Conventional Commit template — match this repo's history.

```bash
# edit .gitignore — add .worktrees/ (or worktrees/) so workspace contents stay untracked
jj commit -m "<message composed from the standards above>"
```

The commit message must describe adding the workspace ignore entry, composed per the Go wiki and this repo's past messages.

**Why critical:** Prevents accidentally committing workspace contents to repository.

#### Create the Workspace

```bash
# Determine path based on chosen location
path="$LOCATION/$BRANCH_NAME"

jj workspace add "$path" --name "$BRANCH_NAME" -r @
cd "$path"
jj bookmark create "$BRANCH_NAME" -r @
```

Alternatively: create the bookmark first, then add a workspace checked out on it:

```bash
jj bookmark create "$BRANCH_NAME" -r @
jj workspace add "$path" --name "$BRANCH_NAME" -r "$BRANCH_NAME"
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
| Already in non-default jj workspace or under `.worktrees/` | Skip creation (Step 0) |
| Nested throwaway checkout | Treat as normal repo (Step 0 guard) |
| Native workspace tool available | Use it (Step 1a) |
| No native tool | Jujutsu workspace fallback (Step 1b) |
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
| "I'm obviously not in a workspace — no need to check" | Run Step 0. Harness-created isolation and nested checkouts both fool eyeballing; the detection commands settle it. |
| "`jj workspace add` is quicker than hunting for a native tool" | A native tool (e.g. `EnterWorktree`) owns placement, bookmarks, and cleanup. Bypassing it is the #1 mistake — it creates phantom state your harness can't see or manage. |
| "The workspace directory is surely ignored already" | Verify `.gitignore` lists the directory. An unignored workspace directory commits the whole tree into the repo. |
| "Any directory name works" | Explicit instructions beat an existing project-local directory, which beats the `.worktrees/` default. |
| "The workspace is fresh — baseline tests can wait" | A dirty baseline makes every later failure ambiguous. Run the tests now; proceeding past failures is your human partner's call. |
