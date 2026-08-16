---
name: using-jj-workspaces
description: Use when starting feature work that needs isolation from the current workspace or before executing implementation plans - ensures an isolated workspace exists with Jujutsu
---

# Using Jujutsu Workspaces

## Overview

Ensure work happens in an isolated Jujutsu workspace. Each workspace has its own working-copy commit and sparse patterns while sharing the same repository.

**Core principle:** Detect existing isolation first. Then use `jj workspace`. Never fight the runtime.

**Announce at start:** "I'm using the using-jj-workspaces skill to set up an isolated workspace."

## Step 0: Detect Existing Isolation

**Before creating anything, check if you are already in an isolated workspace.**

```bash
root=$(jj workspace root)
jj workspace list -T 'name ++ "\t" ++ root ++ "\n"'
```

Match the canonical current root to the listing and record its workspace name.
Use runtime-provided context to determine whether that workspace was already
provisioned for this task. Do not infer isolation merely from the presence of
`.jj`; every Jujutsu workspace has one.

When running POSIX shell commands under Git Bash or another Windows compatibility
shell, normalize paths returned by Jujutsu with `cygpath -u` before passing them
to `dirname`, `mkdir`, `cd`, or other POSIX filesystem commands.

**If already provisioned:** Report "Already in isolated workspace at `<path>`." Skip to Step 2. Do NOT create another workspace.

Has the user already indicated their workspace preference in your instructions? If not, ask for consent before creating a workspace:

> "Would you like me to set up an isolated Jujutsu workspace? It keeps this task's working-copy changes separate from the current workspace."

Honor any existing declared preference without asking. If the user declines consent, work in place and skip to Step 2.

## Step 1: Create Isolated Workspace

#### Directory Selection

Follow this priority order. Explicit user preference always beats observed filesystem state.

1. **Check your instructions for a declared workspace directory preference.** If the user has already specified one, use it without asking.

2. **Check for an existing sibling workspace container:**
   ```bash
   root=$(jj workspace root)
   container="$(dirname "$root")/.workspaces/$(basename "$root")"
   ls -d "$container" 2>/dev/null
   ```
   If found, use it.

3. **If there is no other guidance available**, use that sibling container. Keeping additional workspaces outside the current workspace root prevents their files from being auto-tracked by the current working-copy commit.

#### Safety Verification

Before creating the workspace:

```bash
name="<workspace-name>"
path="$container/$name"

jj workspace list
test ! -e "$path"
```

Choose a unique workspace name and destination. Do not overwrite an existing path or reuse a listed workspace name. A user-selected destination inside the current workspace root must be ignored before proceeding; otherwise choose the sibling container.

**Why critical:** Jujutsu automatically snapshots new files unless they are ignored. A nested workspace can therefore contaminate the current working-copy commit.

#### Create the Workspace

```bash
mkdir -p "$container"
jj workspace add --name "$name" "$path"
cd "$path"
```

By default, `jj workspace add` creates a new working-copy commit with the same parent(s) as the current working-copy commit. Use `--revision <revision>` only when the user or plan requires a different base. Do not create a bookmark merely to identify the workspace.

**Sandbox fallback:** If `jj workspace add` fails with a permission error, tell the user the sandbox blocked workspace creation and work in the current directory instead. Then run setup and baseline tests in place.

**Stale workspace:** If Jujutsu reports that this workspace is stale, run `jj workspace update-stale`. Do not use it speculatively; updating can create a recovery commit when an operation was lost.

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
| Already in a task workspace | Skip creation (Step 0) |
| Explicit directory preference | Use it if safe |
| No directory preference | Use sibling `.workspaces/<project>/` |
| Destination exists or name is listed | Choose a unique path and name |
| Requested destination is inside current root | Verify it is ignored or use sibling default |
| Permission error on create | Sandbox fallback, work in place |
| Workspace reported stale | Run `jj workspace update-stale` |
| Tests fail during baseline | Report failures + ask |
| No package.json/Cargo.toml | Skip dependency install |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "I'm obviously not in a task workspace - no need to check" | Run Step 0. Runtime-created workspaces are easy to miss, and `.jj` alone does not distinguish them. |
| "A nested workspace is more convenient" | Jujutsu auto-tracks new files. Use a sibling destination unless the nested path is ignored. |
| "Any directory name works" | Explicit instructions beat the safe sibling `.workspaces/<project>/` default. |
| "I should create a bookmark for the workspace" | Workspaces have names and independent working-copy commits; bookmarks are not required. |
| "A stale workspace can be ignored" | Run `jj workspace update-stale` when Jujutsu reports staleness before editing files there. |
| "The workspace is fresh — baseline tests can wait" | A dirty baseline makes every later failure ambiguous. Run the tests now; proceeding past failures is your human partner's call. |
