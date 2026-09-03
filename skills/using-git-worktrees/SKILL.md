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
WS_ROOT=$(jj workspace root 2>/dev/null) || true
# Default workspace name is typically "default"; secondary workspaces have other names
jj workspace list
BOOKMARK=$(jj log -r @ -T 'self.bookmarks().map(|b| b.name()).join(" ")' --no-graph 2>/dev/null)
```

**Isolation check:** Compare the current workspace root to the default workspace's path. If `jj workspace list` shows more than one workspace and the current `jj workspace root` is **not** the default workspace's path, you are already in a secondary (isolated) workspace.

Path heuristic (also reliable): if `WS_ROOT` contains `/.worktrees/` or `/worktrees/`, treat it as an isolated workspace we manage.

**If already in a secondary/isolated workspace:** Skip to Step 2 (Project Setup). Do NOT create another workspace.

Report with bookmark state:
- On a bookmark: "Already in isolated workspace at `<path>` on bookmark `<name>`."
- No bookmark on `@`: "Already in isolated workspace at `<path>` (working copy on unnamed change, externally managed). Bookmark creation needed at finish time."

**If in the default workspace only:** You are in a normal single-workspace checkout.

Has the user already indicated their workspace preference in your instructions? If not, ask for consent before creating a workspace:

> "Would you like me to set up an isolated workspace? It protects your current working copy from changes."

Honor any existing declared preference without asking. If the user declines consent, work in place and skip to Step 2.

## Step 1: Create Isolated Workspace

**You have two mechanisms. Try them in this order.**

### 1a. Native Workspace Tools (preferred)

The user has asked for an isolated workspace (Step 0 consent). Do you already have a way to create one? It might be a harness tool (`session_move`, workspace-enter/create helpers, or similarly named commands/flags). If you do, use it and skip to Step 2.

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
# JJ respects .gitignore — confirm the directory (or a parent pattern) is listed
grep -E '^\.worktrees/?$|^worktrees/?$|^\.worktrees|^worktrees' .gitignore 2>/dev/null
# Also accept a catch-all ignore that covers the path; otherwise inspect .gitignore manually
```

**If NOT ignored:** Add `.worktrees/` (or `worktrees/`) to `.gitignore`, then record the change with a description composed per project standards (see below), then proceed.

Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards. Repository-local syntax from project instructions and `git log` ALWAYS wins.

```bash
# After editing .gitignore — JJ auto-snapshots; finish the change:
jj commit -m "<message composed from the standards above>"
```

**Why critical:** Prevents accidentally tracking workspace contents into the repository.

#### Create the Workspace

```bash
# Determine path and names based on chosen location
BOOKMARK_NAME="<feature-bookmark-name>"
path="$LOCATION/$BOOKMARK_NAME"

# Create secondary workspace (name defaults to basename of destination if --name omitted)
jj workspace add "$path" --name "$BOOKMARK_NAME"
# Optional: set parents at creation time — jj workspace add "$path" --name "$BOOKMARK_NAME" -r <base-bookmark>

cd "$path"

# Start a fresh change on the intended base (e.g. main, master, trunk)
jj new <base-bookmark>

# Name the work with a bookmark on the working-copy change
jj bookmark create "$BOOKMARK_NAME" -r @
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
| Already in secondary/isolated workspace | Skip creation (Step 0) |
| Current root is default workspace only | Treat as normal single-workspace repo (Step 0) |
| Native workspace tool available | Use it (Step 1a) |
| No native tool | JJ workspace fallback (Step 1b) |
| `.worktrees/` exists | Use it (verify ignored) |
| `worktrees/` exists | Use it (verify ignored) |
| Both exist | Use `.worktrees/` |
| Neither exists | Check instruction file, then default `.worktrees/` |
| Directory not ignored | Add to .gitignore + record change |
| Permission error on create | Sandbox fallback, work in place |
| Tests fail during baseline | Report failures + ask |
| No package.json/Cargo.toml | Skip dependency install |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "I'm obviously not in a workspace — no need to check" | Run Step 0. Harness-created isolation fools eyeballing; `jj workspace list` and path comparison settle it. |
| "`jj workspace add` is quicker than hunting for a native tool" | A native harness tool owns placement, bookmarks, and cleanup. Bypassing it is the #1 mistake — it creates phantom state your harness can't see or manage. |
| "The workspace directory is surely ignored already" | Verify `.gitignore` lists it. An unignored workspace directory tracks the whole tree into the repo. |
| "Any directory name works" | Explicit instructions beat an existing project-local directory, which beats the `.worktrees/` default. |
| "The workspace is fresh — baseline tests can wait" | A dirty baseline makes every later failure ambiguous. Run the tests now; proceeding past failures is your human partner's call. |
