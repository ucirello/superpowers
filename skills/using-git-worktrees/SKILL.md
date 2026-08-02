---
name: using-git-worktrees
description: Use when starting feature work that needs isolation from the current workspace or before executing implementation plans - creates and manages an isolated Jujutsu workspace with native jj commands
---

# Using Jujutsu Workspaces

## Overview

Ensure work happens in an isolated Jujutsu workspace. Detect the current repository and workspace first, then use `jj workspace` for creation and inspection. There is no fallback to another workspace mechanism.

**Core principle:** Validate the repository root, respect an existing isolated workspace, and keep all workspace lifecycle operations visible to Jujutsu.

**Announce at start:** "I'm using the using-git-worktrees skill to set up an isolated Jujutsu workspace."

## Step 0: Validate the Repository and Current Workspace

**Before creating anything, verify that the current directory belongs to a Jujutsu repository.**

```bash
if ! ROOT=$(jj workspace root 2>/dev/null); then
  echo "Not inside a Jujutsu workspace." >&2
  exit 1
fi

ROOT=$(cd "$ROOT" && pwd -P)
CURRENT=$(pwd -P)
jj workspace list
```

Do not initialize or colocate a repository automatically. If the root check fails, stop and ask the user how to proceed.

Treat the current workspace as already isolated when either:

- The user's instructions identify it as the task workspace.
- Its root is under the repository-local `.rocketclaw/workspaces/` directory.
- Its name or path clearly identifies it as a harness-created workspace.

If it is already isolated, report `Already in isolated Jujutsu workspace at <path>.` and skip to Step 2. Do not create a workspace inside a workspace.

Otherwise, honor any declared workspace preference. If none exists, ask:

> "Would you like me to create an isolated Jujutsu workspace? It keeps this task's working copy separate from the current workspace."

If the user declines, work in place and skip to Step 2.

## Step 1: Create an Isolated Workspace

### Choose the Location

Use this precedence:

1. An explicit user or repository-local instruction.
2. An existing repository-local `.rocketclaw/workspaces/` directory.
3. `.rocketclaw/workspaces/` under the current workspace root.

Repository-local instructions take precedence over user-global defaults.

```bash
BASE=$(jj workspace root)
LOCATION="$BASE/.rocketclaw/workspaces"
WORKSPACE_NAME="<task-name>"
PATHNAME="$LOCATION/$WORKSPACE_NAME"
```

### Verify Ignore Rules

Because the destination is inside the working copy, `.rocketclaw/` must be ignored before creating it. Read the repository-root `.gitignore` and verify that `/.rocketclaw/`, or an equivalent rule covering that directory, is active.

If it is not ignored, add `/.rocketclaw/` to the repository-root `.gitignore` and describe that change before continuing. Do not create the workspace until the ignore rule is active.

### Create the Workspace

Compose a description for the new workspace's working-copy commit. Repository-local commit-message instructions and repository history take precedence over general guidance. Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards. Do not impose a fixed message syntax or use stock fallback text; use task-specific wording and a neutral placeholder where needed.

```bash
DESCRIPTION="<change-description>"
mkdir -p "$LOCATION"
jj workspace add \
  --name "$WORKSPACE_NAME" \
  "$PATHNAME"
jj -R "$PATHNAME" describe -m "$DESCRIPTION"
cd "$PATHNAME"
```

If `jj workspace add` fails with a permission error caused by the sandbox, tell the user that the sandbox blocked workspace creation and work in the current directory instead. Then run setup and baseline tests in place.

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

Use `$(jj workspace root)/.tmp` for temporary files. If the root cannot be resolved, use `.tmp`; do not use a global temporary directory.

```bash
SCRATCH_DIR="$(jj workspace root 2>/dev/null)/.tmp"
if [ "$SCRATCH_DIR" = "/.tmp" ]; then SCRATCH_DIR=.tmp; fi
mkdir -p "$SCRATCH_DIR"
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

```text
Jujutsu workspace ready at <full-path>
Tests passing (<N> tests, 0 failures)
Ready to implement <feature-name>
```

## Quick Reference

| Situation | Action |
|-----------|--------|
| Root check fails | Stop and ask; do not initialize automatically |
| Already in an isolated workspace | Skip creation and run setup |
| `.rocketclaw/` is not ignored | Add `/.rocketclaw/` to `.gitignore` first |
| Sandbox blocks workspace creation | Report it and work in place |
| Temporary files are needed | Use `$(jj workspace root)/.tmp`, fallback `.tmp` |
| Baseline tests fail | Report failures and ask |
| No package.json/Cargo.toml | Skip dependency install |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "I can tell this is the main workspace without checking" | Run the root and workspace checks. Harness-created and repository-local workspaces are easy to misidentify. |
| "A different workspace command is quicker" | `jj workspace` owns workspace metadata. Bypassing it creates state Jujutsu cannot manage correctly. |
| "The destination is probably ignored" | Verify `.rocketclaw/` before creating nested workspace files. |
| "The workspace is fresh, so baseline tests can wait" | A dirty baseline makes later failures ambiguous. Run the tests now; proceeding past failures is the user's call. |
