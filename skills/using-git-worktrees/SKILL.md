---
name: using-git-worktrees
description: Use when starting feature work that needs isolation from the current workspace or before executing implementation plans - ensures an isolated Jujutsu workspace exists via harness-native tools or jj workspace commands
---

# Using Jujutsu Workspaces

## Overview

Ensure work happens in an isolated Jujutsu workspace. Prefer the harness's native Jujutsu workspace tools. When none are available, use `jj workspace`; do not fall back to another version-control system.

**Core principle:** Detect existing workspace context first. Then use native tools. Then use `jj workspace`. Never fight the harness.

**Announce at start:** "I'm using the using-git-worktrees skill to set up an isolated workspace."

## Step 0: Establish Repository and Workspace Context

**Before creating anything, confirm that the current context is a Jujutsu repository and inspect its workspaces.**

```bash
workspace_root=$(jj workspace root)
jj workspace list
```

`jj workspace root` prints the current workspace root. `jj workspace list` prints every workspace in the repository and its working-copy change; use both outputs rather than inferring context from directory names.

**If the harness already placed this task in a dedicated workspace:** Report "Already in isolated workspace at `<path>` (`<workspace-name>`)." Skip to Step 2. Do not create a workspace inside it.

Determine this from harness context, explicit instructions, and the workspace list. Multiple listed workspaces alone do not prove that the current one is dedicated to this task.

**If `jj workspace root` fails:** Stop and report that this workflow requires a Jujutsu repository. Do not initialize a repository or use a fallback unless the user explicitly asks.

Has the user already indicated their workspace preference in the current instructions? If not, ask for consent before creating one:

> "Would you like me to set up an isolated Jujutsu workspace? It keeps this task's working copy separate from your current work."

Honor an existing declared preference without asking. If the user declines consent, work in place and skip to Step 2.

## Step 1: Create Isolated Workspace

**You have two mechanisms. Try them in this order.**

### 1a. Harness-Native Workspace Tools (preferred)

The user has asked for an isolated workspace. If the harness provides a native tool that creates and enters a **Jujutsu workspace**, use it and skip to Step 2.

Native tools may own directory placement, workspace naming, context switching, and cleanup. Do not bypass them with a manual command. A native tool for another version-control system does not apply.

Only proceed to Step 1b if no harness-native Jujutsu workspace tool is available.

### 1b. Native JJ Workspace Commands

Use `jj workspace add` directly. A workspace gets its own working-copy change; it does not need a bookmark for isolation. Create a bookmark only when the repository's delivery workflow actually requires a named pointer, such as publishing that change.

#### Name and Directory Selection

Workspace names share a repository-wide namespace. Choose a short, unique, task-specific `<workspace-name>`; include the harness or session context when needed to avoid collisions. Check `jj workspace list` before choosing it.

Follow this destination priority. Explicit user instructions and repo-local runtime conventions win over defaults.

1. Use the destination required by the harness, repository instructions, or user.
2. Otherwise use the repository-local temporary namespace: `$WORKSPACE_ROOT/.tmp/workspaces/<workspace-name>` after resolving `WORKSPACE_ROOT=$(jj workspace root 2>/dev/null || pwd -P)`.
3. If that root cannot be resolved but the current directory is confirmed to be the intended repository context, use the repo-local fallback `.tmp/workspaces/<workspace-name>`.

Do not use a shared unnamespaced temporary path. Keep all generated workspace paths scoped by workspace name and current repository context.

#### Temporary Path Safety

Before creating a workspace under `.tmp`, confirm that repository instructions designate it for temporary ignored content. If they do not, ask before changing ignore configuration. Do not create or describe a separate change merely to support workspace setup.

#### Create the Workspace

```bash
WORKSPACE_ROOT=$(jj workspace root 2>/dev/null || pwd -P)
path="$WORKSPACE_ROOT/.tmp/workspaces/$WORKSPACE_NAME"
jj workspace add --name "$WORKSPACE_NAME" "$path"
cd "$path"
jj workspace root
```

By default, `jj workspace add` creates a new working-copy change with the same parents as the current working-copy change. Use `--revision <revset>` only when the task must start from a different explicit revision. Do not add `--message` with a fixed template.

**Sandbox fallback:** If workspace creation fails because the destination is denied, report the blocked path and ask whether to use an allowed destination or work in place. Do not silently switch version-control systems.

## Step 2: Project Setup

Use repository-local instructions and runtime tooling first. Only when the repository provides no setup command, auto-detect a compatible default:

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
Workspace ready at <full-path> (<workspace-name>)
Tests passing (<N> tests, 0 failures)
Ready to implement <feature-name>
```

## Step 4: Cleanup

When the isolated workspace is no longer needed, preserve or deliver its changes according to the repository workflow before cleanup. If the harness created the workspace, use its native cleanup tool.

For a manually created workspace, identify it with `jj workspace list`, then run this from another workspace:

```bash
jj workspace forget "$WORKSPACE_NAME"
```

`jj workspace forget` removes the workspace record but does not delete files. Remove the workspace directory separately only after confirming its changes and untracked files are no longer needed. Bookmarks are independent and should not be deleted merely because a workspace was forgotten.

## Quick Reference

| Situation | Action |
|-----------|--------|
| Already in task-dedicated workspace | Skip creation (Step 0) |
| `jj workspace root` fails | Stop; no VCS fallback |
| Native JJ workspace tool available | Use it (Step 1a) |
| No native tool | Use `jj workspace add` (Step 1b) |
| No destination guidance | Use `$WORKSPACE_ROOT/.tmp/workspaces/<workspace-name>` after resolving the root with JJ or `pwd -P` |
| Workspace name already exists | Choose a unique context-qualified name |
| Different starting revision required | Add `--revision <revset>` |
| Named publication pointer required | Create or move a bookmark at delivery time |
| Permission error on create | Ask for an allowed destination or consent to work in place |
| Tests fail during baseline | Report failures + ask |
| No package.json/Cargo.toml | Skip dependency install |
| Workspace no longer needed | `jj workspace forget <workspace-name>`, then separately remove files |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "I'm obviously isolated; no need to check" | Run `jj workspace root` and `jj workspace list`. Directory names do not establish task context. |
| "A manual command is quicker than finding a native tool" | A harness-native JJ workspace tool owns placement, context switching, and cleanup. Bypassing it creates state the harness may not manage. |
| "A workspace needs a branch-like name" | JJ workspaces already have names and independent working-copy changes. Add a bookmark only for a real publication or repository workflow requirement. |
| "Any temporary directory works" | Explicit instructions and repo-local conventions win; otherwise use the repository-scoped `.tmp/workspaces/<workspace-name>` namespace. |
| "Forgetting a workspace deletes it" | `jj workspace forget` only removes its repository record. Files remain until separately and deliberately removed. |
| "The workspace is fresh — baseline tests can wait" | A dirty baseline makes every later failure ambiguous. Run the tests now; proceeding past failures is your human partner's call. |
