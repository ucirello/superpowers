---
name: using-jj-workspaces
description: Use when starting feature work that needs isolation from current workspace or before executing implementation plans - ensures an isolated workspace exists via native tools or jj workspace fallback
---

# Using JJ Workspaces

## Overview

Ensure work happens in an isolated workspace. Prefer your platform's native workspace tools. Fall back to manual jj workspaces only when no native tool is available.

**Core principle:** Detect existing isolation first. Then use native tools. Then fall back to jj. Never fight the harness.

**Announce at start:** "I'm using the using-jj-workspaces skill to set up an isolated workspace."

## Step 0: Detect Existing Isolation

**Before creating anything, check if you are already in an isolated workspace.**

```bash
WS_ROOT=$(jj workspace root 2>/dev/null)
# Current workspace name (empty if jj unavailable)
WS_NAME=$(jj workspace list -T 'if(self.working_copy(), self.name() ++ "\n", "")' 2>/dev/null | head -1)
# Bookmark(s) on working-copy commit (empty = no bookmark on @)
BOOKMARK=$(jj log -r @ -T 'local_bookmarks.map(|b| b.name()).join(" ")' --no-graph 2>/dev/null)
```

**Path-based isolation (preferred):** If `WS_ROOT` contains `/.worktrees/` or `/worktrees/` (or `/workspaces/`), you are already in an isolated workspace we (or the harness) own.

**Multi-workspace signal:** `jj workspace list` showing more than the default workspace also indicates possible isolation — confirm with the path check above before creating another.

**If already isolated (path under `.worktrees/` / `worktrees/` / `workspaces/`, or clearly a non-default linked workspace):** Skip to Step 2 (Project Setup). Do NOT create another workspace.

Report with bookmark state:
- On a bookmark: "Already in isolated workspace at `<path>` on bookmark `<name>`."
- No bookmark on `@`: "Already in isolated workspace at `<path>` (working-copy commit with no bookmark, externally managed). Bookmark creation needed at finish time."

**If in the default single workspace at repo root (normal checkout):** You are not isolated yet.

Has the user already indicated their workspace preference in your instructions? If not, ask for consent before creating a workspace:

> "Would you like me to set up an isolated workspace? It protects your current working copy from changes."

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

Ensure the chosen directory (`.worktrees` or `worktrees`) is listed in `.gitignore`. JJ respects `.gitignore` in colocated repos.

```bash
# Confirm the path is ignored (grep .gitignore or equivalent project ignore files)
grep -E '^\.worktrees/?$|^worktrees/?$' .gitignore 2>/dev/null
```

**If NOT ignored:** Add to `.gitignore`, then record the change. Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards. Repository-local syntax from project instructions and `git log` ALWAYS wins over Go guidance when they differ.

```bash
# After editing .gitignore (JJ auto-snapshots; no staging step)
jj commit -m "<message composed from the standards above>"
```

**Why critical:** Prevents accidentally committing workspace contents to repository.

#### Create the Workspace

```bash
# Determine path based on chosen location
path="$LOCATION/$NAME"

jj workspace add "$path" --name "$NAME"
# Create a bookmark on the new workspace working copy as needed
jj bookmark create "$NAME" -r "$NAME@"
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
| Already in isolated workspace (path under `.worktrees/` etc.) | Skip creation (Step 0) |
| Default single workspace at repo root | Treat as normal checkout (Step 0) |
| Native workspace tool available | Use it (Step 1a) |
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
| "I'm obviously not in a workspace — no need to check" | Run Step 0. Harness-created isolation fools eyeballing; path + `jj workspace root` / `jj workspace list` settle it. |
| "`jj workspace add` is quicker than hunting for a native tool" | A native tool (e.g. `EnterWorktree`) owns placement, bookmarks, and cleanup. Bypassing it is the #1 mistake — it creates phantom state your harness can't see or manage. |
| "The workspace directory is surely ignored already" | Verify `.gitignore` lists it. An unignored workspace directory commits the whole tree into the repo. |
| "Any directory name works" | Explicit instructions beat an existing project-local directory, which beats the `.worktrees/` default. |
| "The workspace is fresh — baseline tests can wait" | A dirty baseline makes every later failure ambiguous. Run the tests now; proceeding past failures is your human partner's call. |
