---
name: using-git-worktrees
description: Use when starting feature work that needs isolation from the current workspace or before executing implementation plans - ensures an isolated JJ workspace exists
---

# Using JJ Workspaces

## Overview

Ensure work happens in an isolated JJ workspace with its own working-copy commit. Detect existing isolation first, then create a workspace only when needed.

**Core principle:** Detect existing isolation first. Then use `jj workspace` commands. Do not infer bookmark movement from workspace creation or later changes.

**Announce at start:** "I'm using the using-git-worktrees skill to set up an isolated JJ workspace."

## Step 0: Detect Existing Isolation

**Before creating anything, inspect the current JJ workspace and attached workspaces.**

```bash
CURRENT_ROOT=$(jj workspace root)
jj workspace list
```

Use `jj workspace root --name <name>` when needed to identify a listed workspace's path. If the current workspace is already the isolated workspace selected for this task, skip to Step 2. Do not create a nested or duplicate workspace.

Report: "Already in isolated JJ workspace at `<path>`."

If the current workspace is not already the task's isolated workspace, check whether the user has declared a workspace preference. If not, ask for consent:

> "Would you like me to set up an isolated JJ workspace? It keeps this task's working-copy commit separate from your current workspace."

Honor any existing declared preference without asking. If the user declines consent, work in place and skip to Step 2.

## Step 1: Create Isolated JJ Workspace

### Harness-Native Isolation (preferred)

Do you have a tool with a name like `EnterWorktree`, `WorktreeCreate`, a `/worktree` command, or a `--worktree` flag? **If yes, and it supports JJ workspaces, use it now and skip to Step 2.** Native tools handle directory placement, workspace creation, and cleanup automatically. Using `jj workspace add` when you have a compatible native tool creates phantom state your harness cannot see or manage.

Some native tools create Git worktrees but do not attach JJ workspaces. A Git worktree is not automatically a JJ workspace: do not use a native tool in a JJ repository unless the harness documents JJ compatibility. Only proceed with manual `jj workspace add` when no JJ-compatible native isolation facility is available.

### Directory Selection

Follow this priority order. Explicit user preference always beats observed filesystem state.

1. **Check instructions for a declared workspace directory preference.** If the user specified one, use it without asking.

2. **Check for an existing project-local workspace directory:**
   ```bash
   ls -d .workspaces 2>/dev/null
   ls -d workspaces 2>/dev/null
   ```
   If both exist, `.workspaces` wins.

3. **If there is no other guidance**, use `.tmp/workspaces/` under the current repository workspace root:
   ```bash
   if ROOT=$(jj workspace root 2>/dev/null); then
       LOCATION="$ROOT/.tmp/workspaces"
    else
        printf '%s\n' "No JJ repository; cannot create a JJ workspace" >&2
        printf '%s\n' "Work in the current directory and use ./.tmp only for temporary storage" >&2
        exit 1
   fi
   ```
   Use the local `./.tmp/workspaces` fallback only when no JJ repository exists. Do not substitute an OS temporary directory.

### Safety Verification

**MUST verify a project-local destination is ignored before creating a workspace inside it.** JJ snapshots working-copy files automatically; there is no index or staging area to protect an unignored nested workspace. When using the default destination, ensure the repository root's ignore file ignores `.tmp/` itself, not only `.tmp/workspaces/` or one generated child path.

Create a temporary probe file under the chosen location and run `jj file list <probe-path>`. If the probe is listed, the location is not ignored. Remove the probe after checking.

**If not ignored:** Add the required rule to the repository's ignore file and record that as a separate change before proceeding. For the default destination, add the root `.tmp/` rule.

Based on https://go.dev/wiki/CommitMessage and on past commit messages that you can see in `git log`, compose commit messages adherent to the present standards.

Repository-local instructions and the message syntax and history visible in `git log` always take precedence; apply Go guidance only where compatible. Preserve the semantic requirement that the message explain the ignore rule needed for workspace isolation, but impose no fixed prefix, type, scope, subject, body, or template. Record the ignore-file change noninteractively with `jj commit -m "<message composed from the standards above>" <ignore-file>`.

**Why critical:** Prevents the containing workspace from snapshotting the nested workspace's files.

### Create the Workspace

Choose the base revision explicitly. Unless the user or plan names another base, use `@`; do not assume the default behavior of `jj workspace add` selects the desired revision.

```bash
case "$WORKSPACE_NAME" in
    ''|.|..|*/*) printf '%s\n' "Invalid JJ workspace name" >&2; exit 1 ;;
esac

path="$LOCATION/$WORKSPACE_NAME"
BASE_REVISION=${BASE_REVISION:-@}

# Establish provenance outside the new working copy when using the default location.
PROVENANCE=
if [ "$LOCATION" = "$ROOT/.tmp/workspaces" ]; then
    PROVENANCE="$LOCATION/.rocketclaw-owned/$WORKSPACE_NAME"
    mkdir -p "$LOCATION/.rocketclaw-owned" || exit 1
    [ ! -e "$PROVENANCE" ] || { printf '%s\n' "Ownership record already exists: $PROVENANCE" >&2; exit 1; }
    (set -C; printf '%s\n' "$path" > "$PROVENANCE") || exit 1
fi

if ! jj workspace add --name "$WORKSPACE_NAME" -r "$BASE_REVISION" "$path"; then
    [ -z "$PROVENANCE" ] || rm -f "$PROVENANCE"
    exit 1
fi

cd "$path"
jj workspace root
```

The `.rocketclaw-owned/<workspace-name>` file is the ownership record for a workspace this skill creates under the repository root's `.tmp/workspaces/`. Its single line is the expected workspace path. Write it without clobbering an existing record before creation, and remove it if `jj workspace add` fails. A marker without a matching attached workspace never authorizes deletion. Harness-created workspaces and workspaces in user-selected locations retain their harness or user ownership semantics and must not receive this marker.

`jj workspace add` creates a new working-copy commit at the selected revision. It does not create or advance a bookmark. Changes made in the workspace also must not be assumed to advance a bookmark.

If a named bookmark is required for publication or a remote operation, set it explicitly at the intended revision when needed:

```bash
jj bookmark set "$BOOKMARK_NAME" -r @
```

Use `jj git` for required Git remote operations. GitHub operations may use `gh`.

**Sandbox fallback:** If `jj workspace add` fails with a permission error, tell the user the sandbox blocked workspace creation and work in the current directory instead. Then run setup and baseline tests in place.

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

Run tests to ensure the workspace starts from a known baseline:

```bash
# Use the project-appropriate command
npm test / cargo test / pytest / go test ./...
```

**If tests fail:** Report failures and ask whether to proceed or investigate.

**If tests pass:** Report ready.

### Report

```
JJ workspace ready at <full-path>
Tests passing (<N> tests, 0 failures)
Ready to implement <feature-name>
```

## Cleanup

When the workspace is no longer needed, stop tracking its working-copy commit from another workspace:

```bash
jj workspace forget "$WORKSPACE_NAME"
```

`jj workspace forget` does not remove files from disk. Delete the workspace directory separately only after confirming its work is preserved.

For a workspace under `<repository-root>/.tmp/workspaces/`, finishing may treat it as owned by this skill only when `.rocketclaw-owned/<workspace-name>` exists and its single line exactly equals the workspace path returned by `jj workspace root --name <workspace-name>`. Confirm the work is preserved, move to another registered workspace, forget the workspace, remove that exact directory, and then remove its marker. Without a matching marker, do not delete it as skill-owned; use the harness's cleanup facility or ask the user. Never infer ownership from the presence or shape of `.jj` files.

## Quick Reference

| Situation | Action |
|-----------|--------|
| Already in the task's JJ workspace | Skip creation |
| User declines isolation | Work in place |
| Explicit directory preference | Use it |
| `.workspaces/` exists | Use it and verify it is ignored |
| `workspaces/` exists | Use it and verify it is ignored |
| Both exist | Use `.workspaces/` |
| Neither exists | Use `<workspace-root>/.tmp/workspaces`; outside a JJ repository, work in place and use local `./.tmp` only for temporary storage |
| Default directory not ignored | Ignore root `.tmp/` and record a separate change |
| JJ-compatible native facility available | Use it and let the harness own cleanup |
| Different base requested | Pass it explicitly with `-r` |
| Bookmark needed | Set it explicitly with `jj bookmark set <name> -r @` |
| Permission error on create | Sandbox fallback, work in place |
| Tests fail during baseline | Report failures and ask |
| No recognized manifest | Skip dependency installation |
| Owned `.tmp/workspaces/` workspace retired | Verify its provenance marker, `jj workspace forget`, then remove the exact directory and marker |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "I'm obviously isolated; no need to check" | Run `jj workspace list` and `jj workspace root`. Existing harness-created workspaces are easy to miss. |
| "Manual creation is quicker than checking native tools" | A JJ-compatible `EnterWorktree`, `WorktreeCreate`, `/worktree`, or `--worktree` facility owns placement and cleanup. Use it; do not create phantom harness state. |
| "Any native worktree tool is compatible" | A Git worktree is not automatically a JJ workspace. Use the native facility only when the harness documents JJ compatibility. |
| "The default revision is probably right" | Pass the intended base with `-r`; the command's default uses the current working-copy commit's parents. |
| "The workspace directory is surely ignored" | Probe it with `jj file list`. JJ automatically snapshots unignored files. |
| "A `.jj` entry proves we created this workspace" | It does not prove ownership. Require the matching `.rocketclaw-owned/<workspace-name>` record before deleting a `.tmp/workspaces/` directory. |
| "Workspace creation made my bookmark" | It did not. Create or set a bookmark explicitly only when needed. |
| "My later changes advanced the bookmark" | Do not assume that. Set the bookmark explicitly to the intended revision before publication. |
| "Any directory name works" | Explicit instructions beat an existing project-local directory, which beats the repository-local `.tmp` default. |
| "The workspace is fresh; baseline tests can wait" | A dirty baseline makes every later failure ambiguous. Run the tests now; proceeding past failures is your human partner's call. |
