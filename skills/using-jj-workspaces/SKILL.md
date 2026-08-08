---
name: using-jj-workspaces
description: Use when starting feature work that needs isolation from the current workspace or before executing implementation plans - ensures an isolated Jujutsu workspace exists via harness-native tools or jj workspace fallback
---

# Using Jujutsu Workspaces

## Overview

Ensure work happens in an isolated workspace. Prefer the harness's native
workspace controls. Fall back to `jj workspace` only when no native control is
available.

**Core principle:** Detect existing isolation first. Then use native tools.
Then fall back to Jujutsu. Never create state the harness cannot manage.

**Announce at start:** "I'm using the using-jj-workspaces skill to set up an isolated workspace."

## Step 0: Detect Existing Isolation

**Before creating anything, inspect the current Jujutsu workspace and the
harness environment.**

```bash
WORKSPACE_ROOT=$(jj workspace root)
jj workspace list
jj status
```

If `jj workspace root` fails, stop and report that the current directory is
not in a Jujutsu repository. Do not silently initialize or convert it.

Treat the current directory as already isolated when the harness says it
created or entered a managed workspace, when a native workspace tool reports
an active workspace, or when the user's instructions identify the current
directory as the task workspace. Skip to Step 2. Do not nest another workspace.

Report: "Already in isolated workspace at `<path>` on change `<change-id>`."

Otherwise, the current Jujutsu workspace may be the user's primary workspace.
Has the user already indicated their workspace preference in the instructions?
If not, ask for consent before creating one:

> "Would you like me to set up an isolated workspace? It protects your current workspace from task changes."

Honor an existing declared preference without asking. If the user declines,
work in place and skip to Step 2.

## Step 1: Create Isolated Workspace

**Use these mechanisms in order.**

### 1a. Harness-Native Workspace Tools (preferred)

If the harness provides a workspace creation or entry tool, command, or flag,
use it and skip to Step 2. The control might be named `EnterWorktree`,
`WorktreeCreate`, `/worktree`, or something equivalent even when the repository
itself uses Jujutsu.

The harness owns placement, lifecycle, and cleanup for workspaces it creates.
Creating a parallel Jujutsu workspace manually can leave state the harness
cannot see or manage.

Only proceed to Step 1b when no native workspace control is available.

### 1b. Jujutsu Workspace Fallback

Create a manual Jujutsu workspace from the selected base revision.

#### Directory Selection

Follow this priority order. Explicit user preference always beats observed
filesystem state.

1. Check the instructions for a declared workspace directory preference. If
   one exists, use it without asking.
2. Use an existing project-local `.workspaces/` or `workspaces/` directory.
   If both exist, `.workspaces/` wins.
3. With no other guidance, default to `.workspaces/` at the project root.

Keep all fallback workspace paths project-local. Do not place them in a global
temporary or configuration directory.

#### Safety Verification

Before creating a project-local workspace, verify that the selected parent
directory is ignored according to the repository's ignore rules. Store that
directory as `WORKSPACE_PARENT`, create it if needed, create a uniquely named
probe file inside it, and run `jj file list <probe>`.
If the probe is listed, remove it, add the parent directory to the repository's
ignore file, and describe that change before proceeding. First ensure the
current change is otherwise empty; if it is not, run `jj new @` so the ignore
edit remains a dedicated change instead of modifying or redescribing existing
work. After describing the ignore-only change, run `jj new`. If the probe is not listed,
remove it and continue. Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards. Repository-local instructions and syntax established by `git log` always win; apply compatible Go guidance to clarity and structure without imposing fixed prefixes, types, scopes, subjects, bodies, or templates. The dynamically composed description must explain that the repository ignore rules now exclude local Jujutsu workspaces.

#### Create the Workspace

Choose the base revision from the approved plan, conversation, or repository
conventions. Use a unique, descriptive workspace name and matching local path.

```bash
REPO_ROOT=$(jj workspace root)
WORKSPACE_PARENT=<selected project-local parent directory>
WORKSPACE_NAME=<feature-name>
mkdir -p "$WORKSPACE_PARENT"
WORKSPACE_PATH="$WORKSPACE_PARENT/$WORKSPACE_NAME"

jj workspace add --name "$WORKSPACE_NAME" -r <base-revision> "$WORKSPACE_PATH"
cd "$WORKSPACE_PATH"
jj status
```

`jj workspace add -r` creates a new working-copy change whose parent is the
selected revision. Do not create a bookmark merely to isolate the work; add a
bookmark only when publishing or when repository conventions require one.

**Sandbox fallback:** If `jj workspace add` fails because the sandbox denies
filesystem access, report that isolation was blocked and ask whether to work in
the current workspace. Do not retry in a global temporary directory.

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

Run tests to ensure the workspace starts clean:

```bash
# Use the project-appropriate command
npm test / cargo test / pytest / go test ./...
```

**If tests fail:** Report failures and ask whether to proceed or investigate.

**If tests pass:** Report ready.

### Report

```
Workspace ready at <full-path>
Working-copy change: <change-id>
Tests passing (<N> tests, 0 failures)
Ready to implement <feature-name>
```

## Quick Reference

| Situation | Action |
|-----------|--------|
| Harness-managed workspace active | Skip creation |
| Native workspace tool available | Use it |
| No native tool | Use `jj workspace add -r` |
| `.workspaces/` exists | Use it |
| `workspaces/` exists | Use it |
| Neither exists | Default to project-local `.workspaces/` |
| Directory not ignored | Update repository ignore rules first |
| Permission error on create | Ask before working in place |
| Tests fail during baseline | Report failures and ask |
| No recognized project manifest | Skip dependency installation |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "This looks like the primary checkout, so it cannot be isolated" | Harness-created workspace state is not reliably visible from the path. Inspect the harness context and `jj workspace list`. |
| "A manual workspace is quicker than finding the native tool" | The harness owns placement and cleanup for its workspaces. Bypassing it creates state the harness cannot manage. |
| "I should create a bookmark with every workspace" | Jujutsu workspaces track working-copy changes directly. A bookmark is needed for publication, not isolation. |
| "A global temporary directory is cleaner" | Fallback workspaces stay with the project so ownership and cleanup remain local and explicit. |
| "The workspace is fresh, so baseline tests can wait" | A dirty baseline makes later failures ambiguous. Run the tests now; proceeding past failures is your human partner's call. |
